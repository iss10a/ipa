import 'season.dart';

class Series {
  const Series({
    required this.seriesId,
    required this.name,
    this.cover,
    this.rating,
    this.categoryId,
    this.plot,
    this.genre,
    this.cast,
    this.director,
    this.releaseDate,
    this.lastModifiedEpoch,
    this.seasons = const [],
  });

  final int seriesId;
  final String name;
  final String? cover;
  final double? rating;
  final String? categoryId;
  final String? plot;
  final String? genre;
  final String? cast;
  final String? director;
  final String? releaseDate;
  final int? lastModifiedEpoch;
  final List<Season> seasons;

  DateTime? get lastModifiedAt => lastModifiedEpoch == null
      ? null
      : DateTime.fromMillisecondsSinceEpoch(lastModifiedEpoch! * 1000);

  Series withSeasons(List<Season> value) => Series(
        seriesId: seriesId,
        name: name,
        cover: cover,
        rating: rating,
        categoryId: categoryId,
        plot: plot,
        genre: genre,
        cast: cast,
        director: director,
        releaseDate: releaseDate,
        lastModifiedEpoch: lastModifiedEpoch,
        seasons: value,
      );
}
