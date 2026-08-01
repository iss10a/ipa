/// A VOD entry. [name] is exactly what the server returned and is never edited.
class Movie {
  const Movie({
    required this.streamId,
    required this.name,
    required this.containerExtension,
    this.icon,
    this.rating,
    this.categoryId,
    this.addedEpoch,
    this.plot,
    this.genre,
    this.cast,
    this.director,
    this.releaseDate,
    this.durationSeconds,
    this.sizeBytes,
  });

  final int streamId;
  final String name;
  final String containerExtension;
  final String? icon;
  final double? rating;
  final String? categoryId;
  final int? addedEpoch;

  // Populated only after a get_vod_info call.
  final String? plot;
  final String? genre;
  final String? cast;
  final String? director;
  final String? releaseDate;
  final int? durationSeconds;
  final int? sizeBytes;

  DateTime? get addedAt => addedEpoch == null
      ? null
      : DateTime.fromMillisecondsSinceEpoch(addedEpoch! * 1000);

  Movie mergeDetails(Movie details) => Movie(
        streamId: streamId,
        name: name,
        containerExtension: details.containerExtension.isNotEmpty
            ? details.containerExtension
            : containerExtension,
        icon: details.icon ?? icon,
        rating: details.rating ?? rating,
        categoryId: categoryId,
        addedEpoch: addedEpoch,
        plot: details.plot,
        genre: details.genre,
        cast: details.cast,
        director: details.director,
        releaseDate: details.releaseDate,
        durationSeconds: details.durationSeconds,
        sizeBytes: details.sizeBytes,
      );
}
