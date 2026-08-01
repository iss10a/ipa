import 'package:flutter_test/flutter_test.dart';
import 'package:pvo/downloader/storage_paths.dart';

void main() {
  group('StoragePaths layout', () {
    test('each film gets its own folder', () {
      expect(
        StoragePaths.movieRelativePath('The Batman 2022', 'mkv'),
        'Movies/The Batman 2022/The Batman 2022.mkv',
      );
    });

    test('movieFolder matches the folder inside movieRelativePath', () {
      const name = 'Dune Part Two';
      final full = StoragePaths.movieRelativePath(name, 'mp4');
      final folder = StoragePaths.movieFolder(name);
      expect(full.startsWith('$folder/'), isTrue);
    });

    test('episodes nest under series then season', () {
      expect(
        StoragePaths.episodeRelativePath(
          rawSeriesName: 'Breaking Bad',
          seasonNumber: 1,
          rawEpisodeTitle: 'Breaking Bad S01E01 Pilot',
          extension: 'mp4',
        ),
        'Series/Breaking Bad/Season 01/Breaking Bad S01E01 Pilot.mp4',
      );
    });

    test('seasonFolder is a prefix of the episode path', () {
      final episode = StoragePaths.episodeRelativePath(
        rawSeriesName: 'Dark',
        seasonNumber: 2,
        rawEpisodeTitle: 'Dark S02E03',
        extension: 'mp4',
      );
      expect(episode.startsWith('${StoragePaths.seasonFolder('Dark', 2)}/'),
          isTrue);
    });

    test('series folder contains every season of that series', () {
      final folder = StoragePaths.seriesFolder('Breaking Bad');
      for (final season in [1, 2, 10]) {
        expect(StoragePaths.seasonFolder('Breaking Bad', season)
            .startsWith('$folder/'), isTrue);
      }
    });

    test('illegal characters are replaced in folder and file alike', () {
      final path = StoragePaths.movieRelativePath('Law & Order: SVU', 'mp4');
      expect(path.contains(':'), isFalse);
      expect(path, 'Movies/Law & Order_ SVU/Law & Order_ SVU.mp4');
    });
  });
}
