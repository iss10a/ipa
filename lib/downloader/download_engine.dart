import '../domain/entities/download_settings.dart';
import '../domain/entities/download_task.dart';

/// Progress emitted by an engine while bytes move.
class EngineProgress {
  const EngineProgress({
    required this.itemId,
    required this.receivedBytes,
    required this.totalBytes,
    required this.speedBytesPerSecond,
    required this.etaSeconds,
  });

  final String itemId;
  final int receivedBytes;
  final int totalBytes;
  final double speedBytesPerSecond;
  final int etaSeconds;
}

/// Terminal outcome of a single task.
class EngineResult {
  const EngineResult({
    required this.itemId,
    required this.status,
    this.error,
    this.receivedBytes = 0,
    this.totalBytes = 0,
    this.isPermanent = false,
  });

  final String itemId;
  final DownloadStatus status;
  final String? error;
  final int receivedBytes;
  final int totalBytes;

  /// True when retrying cannot help, such as a full disk or an unwritable
  /// path. The queue stops instead of looping the whole transfer.
  final bool isPermanent;
}

/// Contract every transport must satisfy. Keeping this abstract is what allows
/// the app to swap between URLSession background transfer and a foreground
/// segmented downloader without the queue or UI knowing the difference.
abstract interface class DownloadEngine {
  /// One-time setup (permissions, callbacks, resumption of orphaned tasks).
  Future<void> initialize();

  /// Begins or resumes [item]. Returns the engine-side task identifier.
  Future<String> start(DownloadItem item, DownloadSettings settings);

  /// Suspends [item], keeping partial bytes for a later resume.
  Future<void> pause(DownloadItem item);

  /// Aborts [item] and discards partial bytes.
  Future<void> cancel(DownloadItem item);

  /// True when this engine can pick up an interrupted transfer mid-file.
  bool get supportsResume;

  /// True when the transfer keeps running after the app is backgrounded.
  bool get survivesBackgrounding;

  Stream<EngineProgress> get progress;
  Stream<EngineResult> get results;

  Future<void> dispose();
}
