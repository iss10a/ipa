import 'download_task.dart';

/// Which transport moves the bytes.
enum EngineMode {
  /// URLSession background transfer. Survives app suspension and termination,
  /// one connection per file. This is the correct default on iOS.
  background,

  /// Dio with HTTP Range segmentation. Faster on servers that allow many
  /// parallel connections, but iOS suspends it once the app leaves foreground.
  turbo,
}

extension EngineModeX on EngineMode {
  String get label => switch (this) {
        EngineMode.background => 'تحميل في الخلفية',
        EngineMode.turbo => 'تسريع (اتصالات متعددة)',
      };

  String get description => switch (this) {
        EngineMode.background =>
          'يكمل التحميل حتى لو أغلقت التطبيق. اتصال واحد لكل ملف.',
        EngineMode.turbo =>
          'يقسّم الملف إلى أجزاء متوازية لسرعة أعلى، لكنه يتوقف عند مغادرة التطبيق.',
      };
}

class DownloadSettings {
  const DownloadSettings({
    this.priority = DownloadPriority.normal,
    this.connections = 4,
    this.maxParallelDownloads = 3,
    this.engineMode = EngineMode.background,
    this.wifiOnly = false,
  });

  final DownloadPriority priority;

  /// 1-16. Only meaningful in [EngineMode.turbo].
  final int connections;

  /// 1-10 concurrent files. Season batches always run sequentially regardless.
  final int maxParallelDownloads;

  final EngineMode engineMode;
  final bool wifiOnly;

  /// High priority raises concurrency within safe bounds; low priority throttles
  /// so the app stays out of the way of whatever else the device is doing.
  /// There is no user-facing throttle any more: downloads always run as fast
  /// as the device and server allow. Season batches stay sequential regardless,
  /// because that ordering is enforced by the queue, not by this limit.
  int get effectiveParallel => 4;

  int get effectiveConnections => 8;

  DownloadSettings copyWith({
    DownloadPriority? priority,
    int? connections,
    int? maxParallelDownloads,
    EngineMode? engineMode,
    bool? wifiOnly,
  }) =>
      DownloadSettings(
        priority: priority ?? this.priority,
        connections: connections ?? this.connections,
        maxParallelDownloads: maxParallelDownloads ?? this.maxParallelDownloads,
        engineMode: engineMode ?? this.engineMode,
        wifiOnly: wifiOnly ?? this.wifiOnly,
      );

  Map<String, dynamic> toJson() => {
        'priority': priority.name,
        'connections': connections,
        'maxParallelDownloads': maxParallelDownloads,
        'engineMode': engineMode.name,
        'wifiOnly': wifiOnly,
      };

  factory DownloadSettings.fromJson(Map<dynamic, dynamic> json) =>
      DownloadSettings(
        priority: DownloadPriority.values.firstWhere(
          (p) => p.name == json['priority'],
          orElse: () => DownloadPriority.normal,
        ),
        connections: json['connections'] as int? ?? 4,
        maxParallelDownloads: json['maxParallelDownloads'] as int? ?? 3,
        engineMode: EngineMode.values.firstWhere(
          (e) => e.name == json['engineMode'],
          orElse: () => EngineMode.background,
        ),
        wifiOnly: json['wifiOnly'] as bool? ?? false,
      );
}
