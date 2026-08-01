enum FavoriteKind { movie, series }

/// A bookmarked title. Stores just enough to rebuild a catalog entity for
/// navigation, so the favourites page works offline without re-querying the
/// server for titles the user already chose.
class FavoriteItem {
  const FavoriteItem({
    required this.id,
    required this.kind,
    required this.sourceId,
    required this.name,
    required this.addedAt,
    this.posterUrl,
    this.rating,
    this.containerExtension,
    this.categoryId,
  });

  /// 'movie:<streamId>' or 'series:<seriesId>'.
  final String id;
  final FavoriteKind kind;

  /// The numeric id on the Xtream server.
  final int sourceId;

  final String name;
  final DateTime addedAt;
  final String? posterUrl;
  final double? rating;

  /// Needed to rebuild the download URL for a film.
  final String? containerExtension;
  final String? categoryId;

  static String movieId(int streamId) => 'movie:$streamId';
  static String seriesId(int seriesId) => 'series:$seriesId';

  Map<String, dynamic> toJson() => {
        'id': id,
        'kind': kind.name,
        'sourceId': sourceId,
        'name': name,
        'addedAt': addedAt.millisecondsSinceEpoch,
        'posterUrl': posterUrl,
        'rating': rating,
        'containerExtension': containerExtension,
        'categoryId': categoryId,
      };

  factory FavoriteItem.fromJson(Map<dynamic, dynamic> json) => FavoriteItem(
        id: json['id'] as String,
        kind: FavoriteKind.values.firstWhere(
          (k) => k.name == json['kind'],
          orElse: () => FavoriteKind.movie,
        ),
        sourceId: json['sourceId'] as int? ?? 0,
        name: json['name'] as String? ?? '',
        addedAt: DateTime.fromMillisecondsSinceEpoch(
            json['addedAt'] as int? ?? 0),
        posterUrl: json['posterUrl'] as String?,
        rating: (json['rating'] as num?)?.toDouble(),
        containerExtension: json['containerExtension'] as String?,
        categoryId: json['categoryId'] as String?,
      );
}
