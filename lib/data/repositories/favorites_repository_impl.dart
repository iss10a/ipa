import '../../domain/entities/favorite.dart';
import '../../domain/repositories/favorites_repository.dart';
import '../datasources/local_store.dart';

class FavoritesRepositoryImpl implements FavoritesRepository {
  FavoritesRepositoryImpl(this._local);

  final LocalStore _local;

  @override
  List<FavoriteItem> loadAll() {
    final items = <FavoriteItem>[];
    for (final row in _local.readFavorites()) {
      try {
        items.add(FavoriteItem.fromJson(row));
      } catch (_) {
        // Ignore an unreadable row instead of hiding the whole list.
      }
    }
    // Newest first, matching how the user last interacted with them.
    items.sort((a, b) => b.addedAt.compareTo(a.addedAt));
    return items;
  }

  @override
  bool contains(String id) => _local.hasFavorite(id);

  @override
  Future<void> add(FavoriteItem item) =>
      _local.writeFavorite(item.id, item.toJson());

  @override
  Future<void> remove(String id) => _local.deleteFavorite(id);
}
