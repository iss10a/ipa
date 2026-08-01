import 'dart:async';

import 'package:flutter/foundation.dart';

import '../domain/entities/download_settings.dart';
import '../domain/entities/download_task.dart';
import '../domain/repositories/download_repository.dart';
import 'download_engine.dart';
import 'storage_paths.dart';

/// Central scheduler. Owns the authoritative list of downloads and decides what
/// runs when.
///
/// Two rules drive every decision:
///   1. At most [DownloadSettings.effectiveParallel] files transfer at once.
///   2. Items sharing a `groupId` (a season batch) are strictly sequential —
///      episode two never starts until episode one reaches a terminal state.
class DownloadQueueManager extends ChangeNotifier {
  DownloadQueueManager({
    required DownloadRepository repository,
    required StoragePaths paths,
    required DownloadEngine engine,
    required DownloadSettings settings,
  })  : _repository = repository,
        _paths = paths,
        _engine = engine,
        _settings = settings;

  final DownloadRepository _repository;
  final StoragePaths _paths;

  DownloadEngine _engine;
  DownloadSettings _settings;

  final Map<String, DownloadItem> _items = {};
  StreamSubscription<EngineProgress>? _progressSub;
  StreamSubscription<EngineResult>? _resultSub;

  /// Coalesces disk writes; progress fires far too often to persist every tick.
  Timer? _persistTimer;
  final Set<String> _dirty = {};

  bool _disposed = false;

  List<DownloadItem> get items {
    final list = _items.values.toList();
    list.sort(_compare);
    return list;
  }

  DownloadSettings get settings => _settings;

  List<DownloadItem> get active =>
      items.where((i) => !i.status.isTerminal).toList();

  List<DownloadItem> get completed =>
      items.where((i) => i.status == DownloadStatus.completed).toList();

  int get activeCount =>
      _items.values.where((i) => i.status == DownloadStatus.running).length;

  static int _compare(DownloadItem a, DownloadItem b) {
    // Running first so the user sees movement at the top of the list.
    final aRunning = a.status == DownloadStatus.running ? 0 : 1;
    final bRunning = b.status == DownloadStatus.running ? 0 : 1;
    if (aRunning != bRunning) return aRunning - bRunning;

    final byPriority = a.priority.weight.compareTo(b.priority.weight);
    if (byPriority != 0) return byPriority;

    if (a.groupId != null && a.groupId == b.groupId) {
      return a.sequenceIndex.compareTo(b.sequenceIndex);
    }
    return a.createdAt.compareTo(b.createdAt);
  }

  Future<void> initialize() async {
    final stored = await _repository.loadAll();
    for (final item in stored) {
      _items[item.id] = item;
    }
    await _engine.initialize();
    _bindEngine();
    notifyListeners();
    _pump();
  }

  void _bindEngine() {
    _progressSub?.cancel();
    _resultSub?.cancel();
    _progressSub = _engine.progress.listen(_onProgress);
    _resultSub = _engine.results.listen(_onResult);
  }

  /// Swaps the transport at runtime (user changed the engine in settings).
  Future<void> swapEngine(DownloadEngine engine) async {
    final running = _items.values
        .where((i) => i.status == DownloadStatus.running)
        .toList();
    for (final item in running) {
      await _engine.pause(item);
      _items[item.id] = item.copyWith(status: DownloadStatus.paused);
    }
    await _progressSub?.cancel();
    await _resultSub?.cancel();

    _engine = engine;
    await _engine.initialize();
    _bindEngine();
    notifyListeners();
  }

  Future<void> updateSettings(DownloadSettings value) async {
    _settings = value;
    notifyListeners();
    _pump();
  }

  // ------------------------------------------------------------------- adding

  /// Result of asking the queue to download something, so the caller can say
  /// something accurate instead of a generic "already exists".
  Future<EnqueueOutcome> enqueue(DownloadItem item) async {
    final existing = _items[item.id];

    if (existing != null) {
      switch (existing.status) {
        case DownloadStatus.completed:
          // Trust the filesystem over the row: if the file was removed behind
          // the app's back, the record is stale and the item must requeue.
          if (await _paths.exists(existing.relativePath)) {
            return EnqueueOutcome.alreadyCompleted;
          }
          _update(existing.copyWith(
            status: DownloadStatus.queued,
            receivedBytes: await _paths.sizeOf(existing.relativePath),
            clearError: true,
          ));
          _pump();
          return EnqueueOutcome.restarted;

        case DownloadStatus.running:
        case DownloadStatus.queued:
          return EnqueueOutcome.alreadyQueued;

        case DownloadStatus.paused:
        case DownloadStatus.failed:
        case DownloadStatus.canceled:
          // Never create a second job for the same content: resume the one
          // that is already on record and keep whatever bytes it has.
          _update(existing.copyWith(
            status: DownloadStatus.queued,
            clearError: true,
            retryCount: 0,
          ));
          _pump();
          return EnqueueOutcome.resumed;
      }
    }

    // Not in the database. The file may still be on disk from an earlier
    // install or a cleared queue, in which case adopt it instead of refetching.
    if (await _paths.exists(item.relativePath)) {
      final size = await _paths.sizeOf(item.relativePath);
      final done = item.copyWith(
        status: DownloadStatus.completed,
        receivedBytes: size,
        totalBytes: size,
      );
      _items[item.id] = done;
      await _repository.upsert(done);
      notifyListeners();
      return EnqueueOutcome.adoptedExistingFile;
    }

    final queued = item.copyWith(status: DownloadStatus.queued);
    _items[item.id] = queued;
    await _repository.upsert(queued);
    notifyListeners();
    _pump();
    return EnqueueOutcome.queued;
  }

  /// Adds a whole season. Every episode enters the queue immediately, but the
  /// shared groupId guarantees they transfer one after another, in order.
  Future<int> enqueueBatch(List<DownloadItem> batch) async {
    final accepted = <DownloadItem>[];
    for (final item in batch) {
      // Same rule as enqueue: an episode already on record is resumed, never
      // duplicated, and one already on disk is left alone.
      final existing = _items[item.id];
      if (existing != null) {
        if (existing.status == DownloadStatus.paused ||
            existing.status == DownloadStatus.failed ||
            existing.status == DownloadStatus.canceled) {
          _update(existing.copyWith(
            status: DownloadStatus.queued, clearError: true, retryCount: 0));
        }
        continue;
      }
      if (await _paths.exists(item.relativePath)) continue;
      final queued = item.copyWith(status: DownloadStatus.queued);
      _items[item.id] = queued;
      accepted.add(queued);
    }
    if (accepted.isNotEmpty) {
      await _repository.upsertAll(accepted);
      notifyListeners();
      _pump();
    }
    return accepted.length;
  }

  // ---------------------------------------------------------------- controls

  Future<void> pause(String id) async {
    final item = _items[id];
    if (item == null || item.status != DownloadStatus.running) return;
    await _engine.pause(item);
    _update(item.copyWith(status: DownloadStatus.paused));
    _pump();
  }

  Future<void> resume(String id) async {
    final item = _items[id];
    if (item == null) return;
    if (item.status != DownloadStatus.paused &&
        item.status != DownloadStatus.failed) {
      return;
    }
    _update(item.copyWith(
      status: DownloadStatus.queued,
      clearError: true,
      retryCount: 0,
    ));
    _pump();
  }

  Future<void> retry(String id) => resume(id);

  Future<void> cancel(String id) async {
    final item = _items[id];
    if (item == null) return;
    await _engine.cancel(item);
    _update(item.copyWith(
      status: DownloadStatus.canceled,
      receivedBytes: 0,
      speedBytesPerSecond: 0,
      etaSeconds: 0,
    ));
    _pump();
  }

  /// Removes the row and, when [deleteFile] is set, the bytes on disk too.
  Future<void> remove(String id, {bool deleteFile = true}) async {
    final item = _items.remove(id);
    if (item == null) return;
    if (item.status.isActive || item.status == DownloadStatus.paused) {
      await _engine.cancel(item);
    } else if (deleteFile) {
      await _paths.deleteFile(item.relativePath);
    }
    await _repository.remove(id);
    notifyListeners();
    _pump();
  }

  Future<void> removeMany(Iterable<String> ids,
      {bool deleteFile = true}) async {
    for (final id in ids.toList()) {
      await remove(id, deleteFile: deleteFile);
    }
  }

  /// Deletes one film: its queue row and the folder holding its file.
  Future<void> removeMovie(String id) async {
    final item = _items[id];
    if (item == null) return;
    await remove(id, deleteFile: true);
    await _paths.deleteDirectory(StoragePaths.movieFolder(item.displayName));
  }

  /// Deletes an entire series: every episode row plus the series folder, so no
  /// orphaned season directories are left behind.
  Future<void> removeSeries(String seriesTitle) async {
    final ids = _items.values
        .where((i) => i.seriesTitle == seriesTitle)
        .map((i) => i.id)
        .toList();
    await removeMany(ids, deleteFile: true);
    await _paths.deleteDirectory(StoragePaths.seriesFolder(seriesTitle));
  }

  /// Deletes one season of a series.
  Future<void> removeSeason(String seriesTitle, int seasonNumber) async {
    final ids = _items.values
        .where((i) =>
            i.seriesTitle == seriesTitle && i.seasonNumber == seasonNumber)
        .map((i) => i.id)
        .toList();
    await removeMany(ids, deleteFile: true);
    await _paths
        .deleteDirectory(StoragePaths.seasonFolder(seriesTitle, seasonNumber));
  }

  /// Every distinct series present in the queue or already downloaded.
  List<String> get seriesTitles {
    final titles = <String>{};
    for (final item in _items.values) {
      final title = item.seriesTitle;
      if (title != null && title.isNotEmpty) titles.add(title);
    }
    final list = titles.toList()..sort();
    return list;
  }

  List<DownloadItem> episodesOf(String seriesTitle) {
    final list = _items.values
        .where((i) => i.seriesTitle == seriesTitle)
        .toList()
      ..sort((a, b) {
        final bySeason =
            (a.seasonNumber ?? 0).compareTo(b.seasonNumber ?? 0);
        if (bySeason != 0) return bySeason;
        return (a.episodeNumber ?? 0).compareTo(b.episodeNumber ?? 0);
      });
    return list;
  }

  List<DownloadItem> get movies =>
      items.where((i) => i.isMovie).toList();

  Future<void> removeCompleted({bool deleteFile = false}) async {
    final ids = completed.map((i) => i.id).toList();
    await removeMany(ids, deleteFile: deleteFile);
  }

  /// Empties everything that has not finished; completed files stay on disk.
  Future<void> clearQueue() async {
    final ids = _items.values
        .where((i) => i.status != DownloadStatus.completed)
        .map((i) => i.id)
        .toList();
    await removeMany(ids);
  }

  Future<void> pauseAll() async {
    for (final item in _items.values
        .where((i) => i.status == DownloadStatus.running)
        .toList()) {
      await pause(item.id);
    }
  }

  Future<void> resumeAll() async {
    for (final item in _items.values
        .where((i) => i.status == DownloadStatus.paused)
        .toList()) {
      await resume(item.id);
    }
  }

  Future<void> setPriority(String id, DownloadPriority priority) async {
    final item = _items[id];
    if (item == null) return;
    _update(item.copyWith(priority: priority));
    _pump();
  }

  bool isQueuedOrDone(String id) {
    final item = _items[id];
    return item != null && item.status != DownloadStatus.canceled;
  }

  DownloadItem? itemById(String id) => _items[id];

  // --------------------------------------------------------------- scheduling

  void _pump() {
    if (_disposed) return;

    final maxParallel = _settings.effectiveParallel;
    var running = _items.values
        .where((i) => i.status == DownloadStatus.running)
        .toList();

    if (running.length >= maxParallel) return;

    // Groups that already have an in-flight item are blocked for this pass.
    final busyGroups = running
        .map((i) => i.groupId)
        .whereType<String>()
        .toSet();

    final candidates = _items.values
        .where((i) => i.status == DownloadStatus.queued)
        .toList()
      ..sort(_compare);

    for (final candidate in candidates) {
      if (running.length >= maxParallel) break;

      final group = candidate.groupId;
      if (group != null) {
        if (busyGroups.contains(group)) continue;

        // Strict order: only the lowest-index unfinished episode may start.
        final next = _nextInGroup(group);
        if (next == null || next.id != candidate.id) continue;

        busyGroups.add(group);
      }

      final started = candidate.copyWith(
        status: DownloadStatus.running,
        clearError: true,
      );
      _items[candidate.id] = started;
      running = [...running, started];
      notifyListeners();

      unawaited(_startOnEngine(started));
    }
  }

  /// The episode that should transfer next within [groupId].
  DownloadItem? _nextInGroup(String groupId) {
    final pending = _items.values
        .where((i) => i.groupId == groupId && !i.status.isTerminal)
        .where((i) =>
            i.status == DownloadStatus.queued ||
            i.status == DownloadStatus.running)
        .toList()
      ..sort((a, b) => a.sequenceIndex.compareTo(b.sequenceIndex));
    return pending.isEmpty ? null : pending.first;
  }

  Future<void> _startOnEngine(DownloadItem item) async {
    try {
      final taskId = await _engine.start(item, _settings);
      final current = _items[item.id];
      if (current != null) {
        _items[item.id] = current.copyWith(engineTaskId: taskId);
        _markDirty(item.id);
      }
    } catch (e) {
      final current = _items[item.id];
      if (current != null) {
        _update(current.copyWith(
          status: DownloadStatus.failed,
          errorMessage: 'تعذّر بدء التحميل.',
        ));
      }
      _pump();
    }
  }

  // ------------------------------------------------------------ engine events

  void _onProgress(EngineProgress event) {
    final item = _items[event.itemId];
    if (item == null) return;

    // A progress event can arrive just after the terminal one. Without this
    // guard it would flip a finished item back to "downloading".
    if (item.status.isTerminal) return;

    _items[event.itemId] = item.copyWith(
      status: DownloadStatus.running,
      receivedBytes: event.receivedBytes,
      totalBytes: event.totalBytes > 0 ? event.totalBytes : item.totalBytes,
      speedBytesPerSecond: event.speedBytesPerSecond,
      etaSeconds: event.etaSeconds,
    );
    _markDirty(event.itemId);
    notifyListeners();
  }

  Future<void> _onResult(EngineResult event) async {
    final item = _items[event.itemId];
    if (item == null) return;

    switch (event.status) {
      case DownloadStatus.completed:
        // The engine already measured the file it reconciled; fall back to a
        // disk read only if it reported nothing.
        final size = event.receivedBytes > 0
            ? event.receivedBytes
            : await _paths.sizeOf(item.relativePath);
        _update(item.copyWith(
          status: DownloadStatus.completed,
          receivedBytes: size > 0 ? size : item.receivedBytes,
          totalBytes: size > 0 ? size : item.totalBytes,
          speedBytesPerSecond: 0,
          etaSeconds: 0,
          clearError: true,
          clearEngineTaskId: true,
        ));

      case DownloadStatus.failed:
        // A permanent failure (no space, unwritable path) cannot be fixed by
        // downloading the same gigabytes again, so it surfaces immediately.
        if (event.isPermanent) {
          _update(item.copyWith(
            status: DownloadStatus.failed,
            errorMessage: event.error ?? 'فشل التحميل.',
            speedBytesPerSecond: 0,
            etaSeconds: 0,
          ));
          _pump();
          return;
        }
        // Transient failures retry automatically a bounded number of times.
        if (item.retryCount < _maxAutoRetries) {
          _update(item.copyWith(
            status: DownloadStatus.queued,
            retryCount: item.retryCount + 1,
            speedBytesPerSecond: 0,
          ));
          await Future<void>.delayed(
              Duration(seconds: 3 * (item.retryCount + 1)));
        } else {
          _update(item.copyWith(
            status: DownloadStatus.failed,
            errorMessage: event.error ?? 'فشل التحميل.',
            speedBytesPerSecond: 0,
            etaSeconds: 0,
          ));
        }

      case DownloadStatus.paused:
        _update(item.copyWith(
          status: DownloadStatus.paused,
          speedBytesPerSecond: 0,
          etaSeconds: 0,
        ));

      case DownloadStatus.canceled:
        _update(item.copyWith(
          status: DownloadStatus.canceled,
          speedBytesPerSecond: 0,
          etaSeconds: 0,
        ));

      default:
        return;
    }

    _pump();
  }

  static const int _maxAutoRetries = 3;

  // ------------------------------------------------------------- persistence

  void _update(DownloadItem item) {
    _items[item.id] = item;
    _markDirty(item.id);
    notifyListeners();
    // Terminal transitions are written through immediately; losing one of these
    // would leave the queue in a wrong state after a crash.
    if (item.status != DownloadStatus.running) {
      unawaited(_flush());
    }
  }

  void _markDirty(String id) {
    _dirty.add(id);
    _persistTimer ??= Timer(const Duration(seconds: 2), () {
      _persistTimer = null;
      unawaited(_flush());
    });
  }

  Future<void> _flush() async {
    if (_dirty.isEmpty) return;
    final batch = <DownloadItem>[];
    for (final id in _dirty.toList()) {
      final item = _items[id];
      if (item != null) batch.add(item);
    }
    _dirty.clear();
    if (batch.isNotEmpty) await _repository.upsertAll(batch);
  }

  @override
  void dispose() {
    _disposed = true;
    _persistTimer?.cancel();
    unawaited(_flush());
    unawaited(_progressSub?.cancel());
    unawaited(_resultSub?.cancel());
    super.dispose();
  }
}
