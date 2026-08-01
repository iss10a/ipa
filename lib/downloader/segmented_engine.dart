import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';

import '../data/datasources/xtream_api.dart';
import '../domain/entities/download_settings.dart';
import '../domain/entities/download_task.dart';
import 'download_engine.dart';
import 'storage_paths.dart';

/// Foreground "turbo" engine: splits a file across parallel HTTP Range requests
/// the way a desktop download accelerator does.
///
/// Only used when the user opts in. iOS suspends the process shortly after the
/// app leaves the foreground, so transfers here pause when the user switches
/// away. Every segment keeps its own `.partN` file, which makes a resume after
/// suspension exact rather than approximate.
class SegmentedDownloadEngine implements DownloadEngine {
  SegmentedDownloadEngine(this._dio, this._api, this._paths);

  final Dio _dio;
  final XtreamApi _api;
  final StoragePaths _paths;

  final _progressController = StreamController<EngineProgress>.broadcast();
  final _resultController = StreamController<EngineResult>.broadcast();

  final Map<String, _Job> _jobs = {};

  @override
  bool get supportsResume => true;

  @override
  bool get survivesBackgrounding => false;

  @override
  Stream<EngineProgress> get progress => _progressController.stream;

  @override
  Stream<EngineResult> get results => _resultController.stream;

  @override
  Future<void> initialize() async {}

  @override
  Future<String> start(DownloadItem item, DownloadSettings settings) async {
    if (_jobs.containsKey(item.id)) return item.id;

    await _paths.ensureParent(item.relativePath);
    final job = _Job(item);
    _jobs[item.id] = job;

    unawaited(_run(job, settings));
    return item.id;
  }

  Future<void> _run(_Job job, DownloadSettings settings) async {
    final item = job.item;
    try {
      final probe = await _api.probe(item.url);
      final total = probe.contentLength ?? 0;
      final connections = settings.effectiveConnections;

      final canSegment =
          probe.acceptsRanges && total > _minSegmentableSize && connections > 1;

      job.totalBytes = total;
      _startTicker(job);

      if (canSegment) {
        await _runSegmented(job, total, connections);
      } else {
        await _runSingle(job, total, resumable: probe.acceptsRanges);
      }

      if (job.canceled) return;

      await _assemble(job, segmented: canSegment);
      await _paths.finalize(item.relativePath);

      _emitResult(job, DownloadStatus.completed);
    } catch (e) {
      if (job.paused) {
        _emitResult(job, DownloadStatus.paused);
      } else if (job.canceled) {
        _emitResult(job, DownloadStatus.canceled);
      } else {
        _emitResult(job, DownloadStatus.failed, error: _describe(e));
      }
    } finally {
      job.ticker?.cancel();
      _jobs.remove(job.item.id);
    }
  }

  /// Below this size the coordination overhead outweighs the parallelism.
  static const int _minSegmentableSize = 8 * 1024 * 1024;

  Future<void> _runSegmented(_Job job, int total, int connections) async {
    final chunk = (total / connections).ceil();
    final futures = <Future<void>>[];

    for (var i = 0; i < connections; i++) {
      final start = i * chunk;
      if (start >= total) break;
      final end = ((i + 1) * chunk) - 1 >= total ? total - 1 : ((i + 1) * chunk) - 1;
      futures.add(_downloadSegment(job, index: i, start: start, end: end));
    }

    await Future.wait(futures);
  }

  Future<void> _downloadSegment(
    _Job job, {
    required int index,
    required int start,
    required int end,
  }) async {
    final path = '${_paths.partialPath(job.item.relativePath)}$index';
    final file = File(path);

    var already = await file.exists() ? await file.length() : 0;
    final segmentSize = end - start + 1;

    if (already > segmentSize) {
      // Corrupt leftover from an aborted run; start this segment over.
      await file.delete();
      already = 0;
    }
    job.addReceived(already);
    if (already == segmentSize) return;

    final cancelToken = CancelToken();
    job.tokens.add(cancelToken);

    final response = await _dio.get<ResponseBody>(
      job.item.url,
      cancelToken: cancelToken,
      options: Options(
        responseType: ResponseType.stream,
        headers: {'Range': 'bytes=${start + already}-$end'},
        validateStatus: (s) => s != null && s < 400,
      ),
    );

    final sink = file.openWrite(mode: FileMode.append);
    try {
      await for (final bytes in response.data!.stream) {
        if (job.canceled || job.paused) {
          cancelToken.cancel();
          break;
        }
        sink.add(bytes);
        job.addReceived(bytes.length);
      }
    } finally {
      await sink.flush();
      await sink.close();
    }

    if (job.paused) throw const _PausedSignal();
    if (job.canceled) throw const _CanceledSignal();
  }

  Future<void> _runSingle(
    _Job job,
    int total, {
    required bool resumable,
  }) async {
    final path = _paths.partialPath(job.item.relativePath);
    final file = File(path);

    var already = 0;
    if (resumable && await file.exists()) {
      already = await file.length();
      if (total > 0 && already >= total) return;
    } else if (await file.exists()) {
      // Server cannot resume, so any partial data is useless.
      await file.delete();
    }
    job.addReceived(already);

    final cancelToken = CancelToken();
    job.tokens.add(cancelToken);

    final response = await _dio.get<ResponseBody>(
      job.item.url,
      cancelToken: cancelToken,
      options: Options(
        responseType: ResponseType.stream,
        headers: already > 0 ? {'Range': 'bytes=$already-'} : null,
        validateStatus: (s) => s != null && s < 400,
      ),
    );

    if (job.totalBytes == 0) {
      final len = response.headers.value(Headers.contentLengthHeader);
      final parsed = len == null ? null : int.tryParse(len);
      if (parsed != null) job.totalBytes = parsed + already;
    }

    final sink = file.openWrite(mode: FileMode.append);
    try {
      await for (final bytes in response.data!.stream) {
        if (job.canceled || job.paused) {
          cancelToken.cancel();
          break;
        }
        sink.add(bytes);
        job.addReceived(bytes.length);
      }
    } finally {
      await sink.flush();
      await sink.close();
    }

    if (job.paused) throw const _PausedSignal();
    if (job.canceled) throw const _CanceledSignal();
  }

  /// Concatenates segment files into the single `.part` file, in order.
  Future<void> _assemble(_Job job, {required bool segmented}) async {
    if (!segmented) return;

    final target = File(_paths.partialPath(job.item.relativePath));
    if (await target.exists()) await target.delete();

    final sink = target.openWrite();
    try {
      var index = 0;
      while (true) {
        final part =
            File('${_paths.partialPath(job.item.relativePath)}$index');
        if (!await part.exists()) break;
        await sink.addStream(part.openRead());
        index++;
      }
    } finally {
      await sink.flush();
      await sink.close();
    }

    // Remove the segment files once merged.
    var index = 0;
    while (true) {
      final part = File('${_paths.partialPath(job.item.relativePath)}$index');
      if (!await part.exists()) break;
      await part.delete();
      index++;
    }
  }

  void _startTicker(_Job job) {
    job.ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      final received = job.received;
      final delta = received - job.lastReported;
      job.lastReported = received;

      // Smooth the speed so the UI does not flicker on bursty connections.
      job.smoothedSpeed = job.smoothedSpeed == 0
          ? delta.toDouble()
          : (job.smoothedSpeed * 0.7) + (delta * 0.3);

      final remaining = job.totalBytes - received;
      final eta = job.smoothedSpeed > 0 && remaining > 0
          ? (remaining / job.smoothedSpeed).round()
          : 0;

      _progressController.add(EngineProgress(
        itemId: job.item.id,
        receivedBytes: received,
        totalBytes: job.totalBytes,
        speedBytesPerSecond: job.smoothedSpeed,
        etaSeconds: eta,
      ));
    });
  }

  void _emitResult(_Job job, DownloadStatus status, {String? error}) {
    if (_resultController.isClosed) return;
    _resultController.add(EngineResult(
      itemId: job.item.id,
      status: status,
      error: error,
      receivedBytes: job.received,
      totalBytes: job.totalBytes,
    ));
  }

  @override
  Future<void> pause(DownloadItem item) async {
    final job = _jobs[item.id];
    if (job == null) return;
    job.paused = true;
    for (final token in job.tokens) {
      if (!token.isCancelled) token.cancel('paused');
    }
  }

  @override
  Future<void> cancel(DownloadItem item) async {
    final job = _jobs[item.id];
    if (job != null) {
      job.canceled = true;
      for (final token in job.tokens) {
        if (!token.isCancelled) token.cancel('canceled');
      }
    }
    await _paths.deleteFile(item.relativePath);
    await _deleteSegments(item.relativePath);
  }

  Future<void> _deleteSegments(String relativePath) async {
    var index = 0;
    while (index < 32) {
      final part = File('${_paths.partialPath(relativePath)}$index');
      if (await part.exists()) {
        await part.delete();
      }
      index++;
    }
  }

  String _describe(Object e) {
    if (e is DioException) {
      return switch (e.type) {
        DioExceptionType.connectionTimeout ||
        DioExceptionType.receiveTimeout =>
          'انتهت مهلة الاتصال أثناء التحميل.',
        DioExceptionType.connectionError => 'انقطع الاتصال بالخادم.',
        DioExceptionType.badResponse =>
          'الخادم أرجع رمز ${e.response?.statusCode}.',
        _ => 'فشل التحميل.',
      };
    }
    if (e is FileSystemException) return 'تعذّر الكتابة على التخزين.';
    return 'فشل التحميل.';
  }

  @override
  Future<void> dispose() async {
    for (final job in _jobs.values) {
      job.canceled = true;
      job.ticker?.cancel();
      for (final token in job.tokens) {
        if (!token.isCancelled) token.cancel('dispose');
      }
    }
    _jobs.clear();
    await _progressController.close();
    await _resultController.close();
  }
}

class _Job {
  _Job(this.item);

  final DownloadItem item;
  final List<CancelToken> tokens = [];

  int totalBytes = 0;
  int received = 0;
  int lastReported = 0;
  double smoothedSpeed = 0;
  bool paused = false;
  bool canceled = false;
  Timer? ticker;

  void addReceived(int bytes) => received += bytes;
}

class _PausedSignal implements Exception {
  const _PausedSignal();
}

class _CanceledSignal implements Exception {
  const _CanceledSignal();
}
