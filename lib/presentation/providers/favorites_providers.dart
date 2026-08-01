import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/di/providers.dart';
import '../../domain/entities/favorite.dart';
import '../../domain/entities/movie.dart';
import '../../domain/entities/series.dart';

/// Holds the whole favourites list in memory. It is small by nature, so the
/// entire set is kept in state and every widget rebuilds from one source.
class FavoritesNotifier extends Notifier<List<FavoriteItem>> {
  @override
  List<FavoriteItem> build() =>
      ref.watch(favoritesRepositoryProvider).loadAll();

  bool contains(String id) => state.any((f) => f.id == id);

  Future<void> toggleMovie(Movie movie) async {
    final id = FavoriteItem.movieId(movie.streamId);
    if (contains(id)) return remove(id);

    final item = FavoriteItem(
      id: id,
      kind: FavoriteKind.movie,
      sourceId: movie.streamId,
      name: movie.name,
      addedAt: DateTime.now(),
      posterUrl: movie.icon,
      rating: movie.rating,
      containerExtension: movie.containerExtension,
      categoryId: movie.categoryId,
    );
    await ref.read(favoritesRepositoryProvider).add(item);
    state = [item, ...state];
  }

  Future<void> toggleSeries(Series series) async {
    final id = FavoriteItem.seriesId(series.seriesId);
    if (contains(id)) return remove(id);

    final item = FavoriteItem(
      id: id,
      kind: FavoriteKind.series,
      sourceId: series.seriesId,
      name: series.name,
      addedAt: DateTime.now(),
      posterUrl: series.cover,
      rating: series.rating,
      categoryId: series.categoryId,
    );
    await ref.read(favoritesRepositoryProvider).add(item);
    state = [item, ...state];
  }

  Future<void> remove(String id) async {
    await ref.read(favoritesRepositoryProvider).remove(id);
    state = state.where((f) => f.id != id).toList();
  }
}

final favoritesProvider =
    NotifierProvider<FavoritesNotifier, List<FavoriteItem>>(
        FavoritesNotifier.new);

/// True when the given catalog id is bookmarked. Watching this instead of the
/// whole list keeps a heart button from rebuilding on unrelated changes.
final isFavoriteProvider = Provider.family<bool, String>(
  (ref, id) => ref.watch(favoritesProvider).any((f) => f.id == id),
);

/// Rebuilds a navigable Movie from a stored favourite.
Movie movieFromFavorite(FavoriteItem item) => Movie(
      streamId: item.sourceId,
      name: item.name,
      containerExtension: item.containerExtension ?? 'mp4',
      icon: item.posterUrl,
      rating: item.rating,
      categoryId: item.categoryId,
    );

/// Rebuilds a navigable Series from a stored favourite.
Series seriesFromFavorite(FavoriteItem item) => Series(
      seriesId: item.sourceId,
      name: item.name,
      cover: item.posterUrl,
      rating: item.rating,
      categoryId: item.categoryId,
    );
