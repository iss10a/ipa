import 'package:flutter_test/flutter_test.dart';
import 'package:pvo/domain/entities/favorite.dart';

void main() {
  group('FavoriteItem', () {
    test('ids are namespaced so a film and a series never collide', () {
      expect(FavoriteItem.movieId(7), 'movie:7');
      expect(FavoriteItem.seriesId(7), 'series:7');
      expect(FavoriteItem.movieId(7) == FavoriteItem.seriesId(7), isFalse);
    });

    test('survives a serialisation round trip', () {
      final original = FavoriteItem(
        id: FavoriteItem.movieId(42),
        kind: FavoriteKind.movie,
        sourceId: 42,
        name: 'فيلم تجريبي',
        addedAt: DateTime.fromMillisecondsSinceEpoch(1700000000000),
        posterUrl: 'http://example.com/p.jpg',
        rating: 7.5,
        containerExtension: 'mkv',
        categoryId: '12',
      );

      final restored = FavoriteItem.fromJson(original.toJson());

      expect(restored.id, original.id);
      expect(restored.kind, original.kind);
      expect(restored.sourceId, original.sourceId);
      expect(restored.name, original.name);
      expect(restored.addedAt, original.addedAt);
      expect(restored.rating, original.rating);
      expect(restored.containerExtension, original.containerExtension);
    });

    test('falls back safely when fields are missing', () {
      final restored = FavoriteItem.fromJson({'id': 'series:9'});
      expect(restored.id, 'series:9');
      expect(restored.sourceId, 0);
      expect(restored.name, '');
    });
  });
}
