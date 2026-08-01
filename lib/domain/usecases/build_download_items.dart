import '../../downloader/storage_paths.dart';
import '../entities/credentials.dart';
import '../entities/download_settings.dart';
import '../entities/download_task.dart';
import '../entities/episode.dart';
import '../entities/movie.dart';
import '../entities/season.dart';
import '../entities/series.dart';

/// Translates catalog entities into queue-ready download items.
///
/// This is the single place where a server-supplied title becomes a file path,
/// which keeps the "keep the original name" rule enforceable in one location.
class BuildDownloadItems {
  const BuildDownloadItems();

  DownloadItem forMovie({
    required Movie movie,
    required Credentials credentials,
    required DownloadSettings settings,
  }) {
    return DownloadItem(
      id: 'movie:${movie.streamId}',
      contentId: '${movie.streamId}',
      url: credentials.movieUrl(movie.streamId, movie.containerExtension),
      displayName: movie.name,
      relativePath: StoragePaths.movieRelativePath(
        movie.name,
        movie.containerExtension,
      ),
      priority: settings.priority,
      status: DownloadStatus.queued,
      createdAt: DateTime.now(),
      posterUrl: movie.icon,
      totalBytes: movie.sizeBytes ?? 0,
    );
  }

  DownloadItem forEpisode({
    required Series series,
    required Episode episode,
    required Credentials credentials,
    required DownloadSettings settings,
    String? groupId,
    int sequenceIndex = 0,
  }) {
    return DownloadItem(
      id: 'episode:${episode.id}',
      contentId: episode.id,
      url: credentials.episodeUrl(episode.id, episode.containerExtension),
      displayName: episode.title,
      relativePath: StoragePaths.episodeRelativePath(
        rawSeriesName: series.name,
        seasonNumber: episode.seasonNumber,
        rawEpisodeTitle: episode.title,
        extension: episode.containerExtension,
      ),
      priority: settings.priority,
      status: DownloadStatus.queued,
      createdAt: DateTime.now(),
      groupId: groupId,
      groupTitle: series.name,
      posterUrl: episode.image ?? series.cover,
      seasonNumber: episode.seasonNumber,
      episodeNumber: episode.episodeNumber,
      sequenceIndex: sequenceIndex,
      totalBytes: episode.sizeBytes ?? 0,
    );
  }

  /// Whole season, tagged with a shared group so the queue runs it in order.
  List<DownloadItem> forSeason({
    required Series series,
    required Season season,
    required Credentials credentials,
    required DownloadSettings settings,
  }) {
    final groupId = 'season:${series.seriesId}:${season.number}';
    final sorted = [...season.episodes]
      ..sort((a, b) => a.episodeNumber.compareTo(b.episodeNumber));

    return [
      for (var i = 0; i < sorted.length; i++)
        forEpisode(
          series: series,
          episode: sorted[i],
          credentials: credentials,
          settings: settings,
          groupId: groupId,
          sequenceIndex: i,
        ),
    ];
  }
}
