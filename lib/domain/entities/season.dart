import 'episode.dart';

class Season {
  const Season({
    required this.number,
    required this.episodes,
    this.name,
    this.cover,
    this.overview,
  });

  final int number;
  final List<Episode> episodes;
  final String? name;
  final String? cover;
  final String? overview;

  String get displayName => name?.isNotEmpty == true
      ? name!
      : 'الموسم ${number.toString().padLeft(2, '0')}';
}
