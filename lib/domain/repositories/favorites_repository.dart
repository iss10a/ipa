import '../entities/favorite.dart';

abstract interface class FavoritesRepository {
  List<FavoriteItem> loadAll();
  bool contains(String id);
  Future<void> add(FavoriteItem item);
  Future<void> remove(String id);
}
