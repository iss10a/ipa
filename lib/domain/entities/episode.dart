/// A single episode. [title] is the raw server title, used verbatim on disk
/// after minimal sanitisation and shown untouched in the UI.
class Episode {
  const Episode({
    required this.id,
    required this.title,
    required this.seasonNumber,
    required this.episodeNumber,
    required this.containerExtension,
    this.plot,
    this.image,
    this.durationSeconds,
    this.sizeBytes,
  });

  final String id;
  final String title;
  final int seasonNumber;
  final int episodeNumber;
  final String containerExtension;
  final String? plot;
  final String? image;
  final int? durationSeconds;
  final int? sizeBytes;
}
