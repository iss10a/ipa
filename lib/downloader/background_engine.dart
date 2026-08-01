import 'dart:async';

import 'dart:io';

import 'package:background_downloader/background_downloader.dart' as bd;

import '../core/constants/app_constants.dart';
import '../domain/entities/download_settings.dart';
import '../domain/entities/download_task.dart';
import 'download_engine.dart';
import 'storage_paths.dart';

/// Default engine. Wraps `background_downloader`, which sits on top of
/// NSURLSession background transfer on iOS, so transfers continue while the app
/// is suspended and are handed back to the app when it relaunches.
///
/// Trade-off: URLSession owns the socket, so exactly one connection per file.
/// Segmented multi-connection downloading is not possible in this mode.
class BackgroundDownloadEngine implements DownloadEngine {
  BackgroundDownloadEngine(this._paths);

  final StoragePaths _paths;

  final _progressController = StreamController<EngineProgress>.broadcast();
  final _resultController = StreamController<EngineResult>.broadcast();

  /// Maps our stable item id to the engine task, needed for pause/cancel.
  final Map<String, bd.DownloadTask> _tasks = {};

  /// Canonical relative path per task id, used to reconcile where the plugin
  /// actually wrote the file.
  final Map<String, String> _relativePaths = {};

  /// Resume data captured on pause, required for a byte-accurate restart.
  final Set<String> _pausedIds = {};

  StreamSubscription<bd.TaskUpdate>? _subscription;
  bool _initialized = false;

  @override
  bool get supportsResume => true;

  @override
  bool get survivesBackgrounding => true;

  @override
  Stream<EngineProgress> get progress => _progressController.stream;

  @override
  Stream<EngineResult> get results => _resultController.stream;

  @override
  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;

    // trackTasks persists task state in the plugin's own database, which is
    // what lets a transfer that completed while the app was killed be reported
    // back on the next launch.
    await bd.FileDownloader().trackTasks();

    _subscription = bd.FileDownloader().updates.listen(_onUpdate);
  }

  @override
  Future<String> start(DownloadItem item, DownloadSettings settings) async {
    await _paths.ensureParent(item.relativePath);

    final existing = _tasks[item.id];
    if (existing != null && _pausedIds.contains(item.id)) {
      final resumed = await bd.FileDownloader().resume(existing);
      if (resumed) {
        _pausedIds.remove(item.id);
        return existing.taskId;
      }
      // Resume data expired; fall through to a fresh enqueue.
    }

    final task = bd.DownloadTask(
      taskId: item.id,
      url: item.url,
      filename: _fileName(item.relativePath),
      directory: _directory(item.relativePath),
      baseDirectory: bd.BaseDirectory.applicationSupport,
      updates: bd.Updates.statusAndProgress,
      allowPause: true,
      retries: 3,
      requiresWiFi: settings.wifiOnly,
      priority: _mapPriority(settings.priority),
      metaData: item.groupId ?? '',
    );

    _tasks[item.id] = task;
    _relativePaths[item.id] = item.relativePath;
    _pausedIds.remove(item.id);

    final enqueued = await bd.FileDownloader().enqueue(task);
    if (!enqueued) {
      _resultController.add(EngineResult(
        itemId: item.id,
        status: DownloadStatus.failed,
        error: 'تعذّر بدء التحميل.',
      ));
    }
    return task.taskId;
  }

  @override
  Future<void> pause(DownloadItem item) async {
    final task = _tasks[item.id];
    if (task == null) return;
    final paused = await bd.FileDownloader().pause(task);
    if (paused) {
      _pausedIds.add(item.id);
    } else {
      // Server does not support Range: the only honest option is to cancel and
      // report it, rather than pretending the partial file is resumable.
      await bd.FileDownloader().cancelTaskWithId(task.taskId);
      _resultController.add(EngineResult(
        itemId: item.id,
        status: DownloadStatus.failed,
        error: 'الخادم لا يدعم الإيقاف المؤقت لهذا الملف.',
      ));
    }
  }

  @override
  Future<void> cancel(DownloadItem item) async {
    final task = _tasks.remove(item.id);
    _pausedIds.remove(item.id);
    if (task != null) {
      await bd.FileDownloader().cancelTaskWithId(task.taskId);
    }
    await _paths.deleteFile(item.relativePath);
  }

  void _onUpdate(bd.TaskUpdate update) {
    final id = update.task.taskId;

    if (update is bd.TaskProgressUpdate) {
      final expected = update.expectedFileSize;
      final total = expected > 0 ? expected : 0;
      final received = total > 0 ? (total * update.progress).round() : 0;

      // Negative progress values are sentinel codes, not real progress.
      if (update.progress < 0) return;

      _progressController.add(EngineProgress(
        itemId: id,
        receivedBytes: received,
        totalBytes: total,
        speedBytesPerSecond: update.networkSpeed > 0
            ? update.networkSpeed * 1024 * 1024
            : 0,
        etaSeconds: update.timeRemaining.inSeconds > 0
            ? update.timeRemaining.inSeconds
            : 0,
      ));
      return;
    }

    if (update is bd.TaskStatusUpdate) {
      final mapped = switch (update.status) {
        bd.TaskStatus.complete => DownloadStatus.completed,
        bd.TaskStatus.canceled => DownloadStatus.canceled,
        bd.TaskStatus.paused => DownloadStatus.paused,
        bd.TaskStatus.failed => DownloadStatus.failed,
        bd.TaskStatus.notFound => DownloadStatus.failed,
        bd.TaskStatus.running => DownloadStatus.running,
        bd.TaskStatus.enqueued => DownloadStatus.queued,
        bd.TaskStatus.waitingToRetry => DownloadStatus.queued,
      };

      if (mapped == DownloadStatus.running ||
          mapped == DownloadStatus.queued) {
        return;
      }
      if (mapped == DownloadStatus.paused) {
        _pausedIds.add(id);
      }
      if (mapped == DownloadStatus.completed) {
        // The plugin owns the final location. Reconcile it with the path the
        // rest of the app expects, instead of assuming the two agree.
        unawaited(_reconcile(id, update.task));
        return;
      }
      if (mapped == DownloadStatus.canceled) {
        _tasks.remove(id);
        _pausedIds.remove(id);
      }

      _resultController.add(EngineResult(
        itemId: id,
        status: mapped,
        // Storage failures are permanent: retrying re-downloads gigabytes and
        // fails again at the same step.
        isPermanent: update.exception is bd.TaskFileSystemException,
        error: mapped == DownloadStatus.failed
            ? _describeException(update.exception)
            : null,
        totalBytes: update.responseHeaders == null
            ? 0
            : int.tryParse(
                    update.responseHeaders?['content-length'] ?? '0') ??
                0,
      ));
    }
  }

  /// Moves the finished file to the path the queue verifies, when the plugin
  /// chose somewhere else, then reports completion with the real size.
  Future<void> _reconcile(String id, bd.Task task) async {
    final expectedRelative = _relativePaths[id];
    var bytes = 0;

    try {
      final actual = await task.filePath();
      final expected = expectedRelative == null
          ? actual
          : _paths.absolute(expectedRelative);

      if (actual != expected) {
        final source = File(actual);
        if (await source.exists()) {
          if (expectedRelative != null) {
            await _paths.ensureParent(expectedRelative);
          }
          final target = File(expected);
          if (await target.exists()) await target.delete();
          await source.rename(target.path);
        }
      }

      final finalFile = File(expected);
      if (await finalFile.exists()) bytes = await finalFile.length();
    } catch (_) {
      // Fall through: a reconcile failure is reported as a failed download
      // rather than silently leaving a half-present file marked complete.
    }

    _tasks.remove(id);
    _pausedIds.remove(id);

    if (bytes <= 0) {
      _resultController.add(EngineResult(
        itemId: id,
        status: DownloadStatus.failed,
        error: 'اكتمل التحميل لكن تعذّر حفظ الملف على الجهاز.',
        isPermanent: true,
      ));
      return;
    }

    _resultController.add(EngineResult(
      itemId: id,
      status: DownloadStatus.completed,
      receivedBytes: bytes,
      totalBytes: bytes,
    ));
  }

  String _describeException(bd.TaskException? exception) {
    if (exception == null) return 'فشل التحميل.';
    return switch (exception) {
      bd.TaskFileSystemException _ => 'لا توجد مساحة كافية على الجهاز.',
      bd.TaskUrlException _ => 'رابط التحميل غير صالح.',
      bd.TaskConnectionException _ => 'انقطع الاتصال بالخادم.',
      final bd.TaskHttpException e => 'الخادم أرجع رمز ${e.httpResponseCode}.',
      _ => 'فشل التحميل: ${exception.description}',
    };
  }

  /// background_downloader uses an integer scale where 0 is most urgent and
  /// 10 is least; 5 is the package default.
  int _mapPriority(DownloadPriority priority) => switch (priority) {
        DownloadPriority.high => 1,
        DownloadPriority.normal => 5,
        DownloadPriority.low => 9,
      };

  /// background_downloader wants the directory relative to the base directory.
  String _directory(String relativePath) {
    final parts = relativePath.split('/');
    if (parts.length <= 1) return AppConstants.downloadsRoot;
    return '${AppConstants.downloadsRoot}/'
        '${parts.sublist(0, parts.length - 1).join('/')}';
  }

  String _fileName(String relativePath) => relativePath.split('/').last;

  @override
  Future<void> dispose() async {
    await _subscription?.cancel();
    await _progressController.close();
    await _resultController.close();
  }
}
