enum DownloadStatus {
  queued,
  running,
  paused,
  completed,
  failed,
  canceled,
}

enum DownloadPriority { low, normal, high }

extension DownloadPriorityX on DownloadPriority {
  /// Lower sorts first in the queue.
  int get weight => switch (this) {
        DownloadPriority.high => 0,
        DownloadPriority.normal => 1,
        DownloadPriority.low => 2,
      };

  String get label => switch (this) {
        DownloadPriority.high => 'عالية',
        DownloadPriority.normal => 'عادية',
        DownloadPriority.low => 'منخفضة',
      };
}

extension DownloadStatusX on DownloadStatus {
  bool get isTerminal =>
      this == DownloadStatus.completed ||
      this == DownloadStatus.canceled;

  bool get isActive =>
      this == DownloadStatus.running || this == DownloadStatus.queued;

  String get label => switch (this) {
        DownloadStatus.queued => 'في الانتظار',
        DownloadStatus.running => 'جارٍ التحميل',
        DownloadStatus.paused => 'متوقف مؤقتاً',
        DownloadStatus.completed => '✓ مكتمل',
        DownloadStatus.failed => 'فشل',
        DownloadStatus.canceled => 'ملغى',
      };
}

/// One downloadable item. Immutable; the queue emits replaced copies.
class DownloadItem {
  const DownloadItem({
    required this.id,
    required this.url,
    required this.displayName,
    required this.relativePath,
    required this.priority,
    required this.status,
    required this.createdAt,
    this.updatedAt,
    this.contentId,
    this.groupId,
    this.groupTitle,
    this.posterUrl,
    this.seasonNumber,
    this.episodeNumber,
    this.sequenceIndex = 0,
    this.receivedBytes = 0,
    this.totalBytes = 0,
    this.speedBytesPerSecond = 0,
    this.etaSeconds = 0,
    this.errorMessage,
    this.retryCount = 0,
    this.engineTaskId,
  });

  /// Stable identity: "movie:<streamId>" or "episode:<episodeId>".
  final String id;
  final String url;

  /// Raw server-provided name, shown to the user unmodified.
  final String displayName;

  /// Path under the Downloads root, already sanitised for the filesystem.
  final String relativePath;

  final DownloadPriority priority;
  final DownloadStatus status;
  final DateTime createdAt;

  /// Last time any field changed. Written on every state transition so the
  /// database can be reasoned about as the single source of truth.
  final DateTime? updatedAt;

  /// Raw server id (stream_id for a film, episode id for an episode), kept
  /// alongside the namespaced [id] so a title can be matched even if its
  /// display name changes on the server between catalog refreshes.
  final String? contentId;

  /// Set for season batches so episodes run strictly one after another.
  final String? groupId;
  final String? groupTitle;

  final String? posterUrl;
  final int? seasonNumber;
  final int? episodeNumber;

  /// Position within the group; enforces episode order.
  final int sequenceIndex;

  final int receivedBytes;
  final int totalBytes;
  final double speedBytesPerSecond;
  final int etaSeconds;
  final String? errorMessage;
  final int retryCount;

  /// Identifier handed back by the active engine, used for pause/cancel.
  final String? engineTaskId;

  double get progress =>
      totalBytes > 0 ? (receivedBytes / totalBytes).clamp(0.0, 1.0) : 0.0;

  /// Ids are namespaced at creation: 'movie:<id>' or 'episode:<id>'.
  bool get isMovie => id.startsWith('movie:');
  bool get isEpisode => id.startsWith('episode:');

  /// Series name for an episode, used to group the downloads library.
  String? get seriesTitle => isEpisode ? groupTitle : null;

  bool get isGrouped => groupId != null;

  DownloadItem copyWith({
    DownloadPriority? priority,
    DownloadStatus? status,
    int? receivedBytes,
    int? totalBytes,
    double? speedBytesPerSecond,
    int? etaSeconds,
    String? errorMessage,
    bool clearError = false,
    int? retryCount,
    String? engineTaskId,
    bool clearEngineTaskId = false,
  }) =>
      DownloadItem(
        id: id,
        url: url,
        displayName: displayName,
        relativePath: relativePath,
        priority: priority ?? this.priority,
        status: status ?? this.status,
        createdAt: createdAt,
        updatedAt: DateTime.now(),
        contentId: contentId,
        groupId: groupId,
        groupTitle: groupTitle,
        posterUrl: posterUrl,
        seasonNumber: seasonNumber,
        episodeNumber: episodeNumber,
        sequenceIndex: sequenceIndex,
        receivedBytes: receivedBytes ?? this.receivedBytes,
        totalBytes: totalBytes ?? this.totalBytes,
        speedBytesPerSecond: speedBytesPerSecond ?? this.speedBytesPerSecond,
        etaSeconds: etaSeconds ?? this.etaSeconds,
        errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
        retryCount: retryCount ?? this.retryCount,
        engineTaskId: clearEngineTaskId
            ? null
            : (engineTaskId ?? this.engineTaskId),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'url': url,
        'displayName': displayName,
        'relativePath': relativePath,
        'priority': priority.name,
        'status': status.name,
        'createdAt': createdAt.millisecondsSinceEpoch,
        'updatedAt': (updatedAt ?? createdAt).millisecondsSinceEpoch,
        'contentId': contentId,
        'groupId': groupId,
        'groupTitle': groupTitle,
        'posterUrl': posterUrl,
        'seasonNumber': seasonNumber,
        'episodeNumber': episodeNumber,
        'sequenceIndex': sequenceIndex,
        'receivedBytes': receivedBytes,
        'totalBytes': totalBytes,
        'errorMessage': errorMessage,
        'retryCount': retryCount,
        'engineTaskId': engineTaskId,
      };

  factory DownloadItem.fromJson(Map<dynamic, dynamic> json) {
    final rawStatus = json['status'] as String? ?? 'queued';
    var status = DownloadStatus.values.firstWhere(
      (s) => s.name == rawStatus,
      orElse: () => DownloadStatus.queued,
    );
    // A task that was mid-flight when the process died resumes as paused so the
    // user decides, rather than silently burning data on launch.
    if (status == DownloadStatus.running) status = DownloadStatus.paused;

    return DownloadItem(
      id: json['id'] as String,
      url: json['url'] as String,
      displayName: json['displayName'] as String,
      relativePath: json['relativePath'] as String,
      priority: DownloadPriority.values.firstWhere(
        (p) => p.name == (json['priority'] as String? ?? 'normal'),
        orElse: () => DownloadPriority.normal,
      ),
      status: status,
      createdAt: DateTime.fromMillisecondsSinceEpoch(
          json['createdAt'] as int? ?? 0),
      updatedAt: json['updatedAt'] == null
          ? null
          : DateTime.fromMillisecondsSinceEpoch(json['updatedAt'] as int),
      contentId: json['contentId'] as String?,
      groupId: json['groupId'] as String?,
      groupTitle: json['groupTitle'] as String?,
      posterUrl: json['posterUrl'] as String?,
      seasonNumber: json['seasonNumber'] as int?,
      episodeNumber: json['episodeNumber'] as int?,
      sequenceIndex: json['sequenceIndex'] as int? ?? 0,
      receivedBytes: json['receivedBytes'] as int? ?? 0,
      totalBytes: json['totalBytes'] as int? ?? 0,
      errorMessage: json['errorMessage'] as String?,
      retryCount: json['retryCount'] as int? ?? 0,
      engineTaskId: json['engineTaskId'] as String?,
    );
  }
}

/// Why a call to enqueue did or did not create work.
enum EnqueueOutcome {
  queued,
  resumed,
  restarted,
  alreadyQueued,
  alreadyCompleted,
  adoptedExistingFile,
}

extension EnqueueOutcomeX on EnqueueOutcome {
  String get message => switch (this) {
        EnqueueOutcome.queued => 'أُضيف إلى قائمة التحميل',
        EnqueueOutcome.resumed => 'استُؤنف التحميل من حيث توقف',
        EnqueueOutcome.restarted => 'الملف مفقود من الجهاز، أُعيد التحميل',
        EnqueueOutcome.alreadyQueued => 'موجود في القائمة بالفعل',
        EnqueueOutcome.alreadyCompleted => 'تم تنزيل هذا الملف مسبقاً.',
        EnqueueOutcome.adoptedExistingFile => 'هذا الملف موجود بالفعل.',
      };
}
