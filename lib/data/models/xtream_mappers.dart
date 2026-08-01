import '../../domain/entities/category.dart';
import '../../domain/entities/episode.dart';
import '../../domain/entities/movie.dart';
import '../../domain/entities/season.dart';
import '../../domain/entities/series.dart';

/// Xtream panels are notoriously loose with types: the same field can arrive as
/// an int, a string, `null`, or an empty string. Every accessor here is
/// defensive so a single malformed row never breaks a whole category.
class Parse {
  Parse._();

  static String str(dynamic v, {String fallback = ''}) {
    if (v == null) return fallback;
    final s = v.toString().trim();
    return s.isEmpty ? fallback : s;
  }

  static String? strOrNull(dynamic v) {
    final s = str(v);
    return s.isEmpty ? null : s;
  }

  static int? intOrNull(dynamic v) {
    if (v == null) return null;
    if (v is int) return v;
    if (v is double) return v.toInt();
    return int.tryParse(v.toString().trim());
  }

  static int intOr(dynamic v, int fallback) => intOrNull(v) ?? fallback;

  static double? doubleOrNull(dynamic v) {
    if (v == null) return null;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString().trim());
  }

  /// Duration may arrive as seconds, or as "01:32:10".
  static int? durationSeconds(Map<dynamic, dynamic> info) {
    final secs = intOrNull(info['duration_secs']);
    if (secs != null && secs > 0) return secs;
    final raw = strOrNull(info['duration']);
    if (raw == null) return null;
    final parts = raw.split(':').map((p) => int.tryParse(p.trim())).toList();
    if (parts.any((p) => p == null)) return null;
    if (parts.length == 3) {
      return parts[0]! * 3600 + parts[1]! * 60 + parts[2]!;
    }
    if (parts.length == 2) return parts[0]! * 60 + parts[1]!;
    return null;
  }
}

class CategoryMapper {
  static Category fromJson(Map<dynamic, dynamic> json, CatalogKind kind) =>
      Category(
        id: Parse.str(json['category_id']),
        name: Parse.str(json['category_name'], fallback: 'بدون تصنيف'),
        kind: kind,
      );

  static List<Category> listFrom(List<dynamic> raw, CatalogKind kind) => raw
      .whereType<Map>()
      .map((e) => CategoryMapper.fromJson(e, kind))
      .where((c) => c.id.isNotEmpty)
      .toList();
}

class MovieMapper {
  static Movie? fromStreamJson(Map<dynamic, dynamic> json) {
    final id = Parse.intOrNull(json['stream_id']);
    final name = Parse.strOrNull(json['name']);
    if (id == null || name == null) return null;

    return Movie(
      streamId: id,
      name: name,
      containerExtension:
          Parse.str(json['container_extension'], fallback: 'mp4'),
      icon: Parse.strOrNull(json['stream_icon']),
      rating: Parse.doubleOrNull(json['rating']),
      categoryId: Parse.strOrNull(json['category_id']),
      addedEpoch: Parse.intOrNull(json['added']),
    );
  }

  static List<Movie> listFrom(List<dynamic> raw) => raw
      .whereType<Map>()
      .map(MovieMapper.fromStreamJson)
      .whereType<Movie>()
      .toList();

  /// Builds the detail-only fields from a `get_vod_info` payload.
  static Movie detailsFrom(Map<dynamic, dynamic> payload, Movie base) {
    final info = (payload['info'] as Map?) ?? const {};
    final movieData = (payload['movie_data'] as Map?) ?? const {};

    return Movie(
      streamId: base.streamId,
      name: base.name,
      containerExtension: Parse.str(
        movieData['container_extension'],
        fallback: base.containerExtension,
      ),
      icon: Parse.strOrNull(info['movie_image']) ?? base.icon,
      rating: Parse.doubleOrNull(info['rating']) ?? base.rating,
      plot: Parse.strOrNull(info['plot']) ??
          Parse.strOrNull(info['description']),
      genre: Parse.strOrNull(info['genre']),
      cast: Parse.strOrNull(info['cast']),
      director: Parse.strOrNull(info['director']),
      releaseDate: Parse.strOrNull(info['releasedate']) ??
          Parse.strOrNull(info['release_date']),
      durationSeconds: Parse.durationSeconds(info),
      sizeBytes: Parse.intOrNull(info['bitrate']) == null
          ? null
          : Parse.intOrNull((info['video'] as Map?)?['size']),
    );
  }
}

class SeriesMapper {
  static Series? fromJson(Map<dynamic, dynamic> json) {
    final id = Parse.intOrNull(json['series_id']);
    final name = Parse.strOrNull(json['name']);
    if (id == null || name == null) return null;

    return Series(
      seriesId: id,
      name: name,
      cover: Parse.strOrNull(json['cover']),
      rating: Parse.doubleOrNull(json['rating']),
      categoryId: Parse.strOrNull(json['category_id']),
      plot: Parse.strOrNull(json['plot']),
      genre: Parse.strOrNull(json['genre']),
      cast: Parse.strOrNull(json['cast']),
      director: Parse.strOrNull(json['director']),
      releaseDate: Parse.strOrNull(json['releaseDate']) ??
          Parse.strOrNull(json['release_date']),
      lastModifiedEpoch: Parse.intOrNull(json['last_modified']),
    );
  }

  static List<Series> listFrom(List<dynamic> raw) => raw
      .whereType<Map>()
      .map(SeriesMapper.fromJson)
      .whereType<Series>()
      .toList();

  /// Parses `get_series_info`, which nests episodes under a season-number key.
  static List<Season> seasonsFrom(Map<dynamic, dynamic> payload) {
    final episodesRaw = payload['episodes'];
    if (episodesRaw is! Map) return const [];

    final seasonMeta = <int, Map<dynamic, dynamic>>{};
    final metaRaw = payload['seasons'];
    if (metaRaw is List) {
      for (final entry in metaRaw.whereType<Map>()) {
        final number = Parse.intOrNull(entry['season_number']);
        if (number != null) seasonMeta[number] = entry;
      }
    }

    final seasons = <Season>[];
    for (final entry in episodesRaw.entries) {
      final seasonNumber = Parse.intOrNull(entry.key) ?? 0;
      final list = entry.value;
      if (list is! List) continue;

      final episodes = <Episode>[];
      for (final e in list.whereType<Map>()) {
        final parsed = _episodeFrom(e, seasonNumber);
        if (parsed != null) episodes.add(parsed);
      }
      if (episodes.isEmpty) continue;

      episodes.sort((a, b) => a.episodeNumber.compareTo(b.episodeNumber));
      final meta = seasonMeta[seasonNumber];

      seasons.add(Season(
        number: seasonNumber,
        episodes: episodes,
        name: meta == null ? null : Parse.strOrNull(meta['name']),
        cover: meta == null ? null : Parse.strOrNull(meta['cover']),
        overview: meta == null ? null : Parse.strOrNull(meta['overview']),
      ));
    }

    seasons.sort((a, b) => a.number.compareTo(b.number));
    return seasons;
  }

  static Episode? _episodeFrom(Map<dynamic, dynamic> json, int seasonNumber) {
    final id = Parse.strOrNull(json['id']);
    if (id == null) return null;

    final info = (json['info'] as Map?) ?? const {};
    final title = Parse.str(json['title'],
        fallback: 'الحلقة ${Parse.intOr(json['episode_num'], 0)}');

    return Episode(
      id: id,
      title: title,
      seasonNumber: Parse.intOr(json['season'], seasonNumber),
      episodeNumber: Parse.intOr(json['episode_num'], 0),
      containerExtension:
          Parse.str(json['container_extension'], fallback: 'mp4'),
      plot: Parse.strOrNull(info['plot']),
      image: Parse.strOrNull(info['movie_image']),
      durationSeconds: Parse.durationSeconds(info),
      sizeBytes: Parse.intOrNull(info['size']),
    );
  }
}
