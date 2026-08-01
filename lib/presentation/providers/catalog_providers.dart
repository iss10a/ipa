import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/di/providers.dart';
import '../../domain/entities/category.dart';
import '../../domain/entities/movie.dart';
import '../../domain/entities/series.dart';
import '../../domain/usecases/filter_catalog.dart';

/// Full VOD list for the active session. Cached by Riverpod, refreshed on pull.
final moviesProvider = FutureProvider.autoDispose<List<Movie>>((ref) async {
  ref.keepAlive();
  final result = await ref.watch(catalogRepositoryProvider).movies();
  return result.fold(
    onSuccess: (value) => value,
    onFailure: (failure) => throw failure,
  );
});

final seriesProvider = FutureProvider.autoDispose<List<Series>>((ref) async {
  ref.keepAlive();
  final result = await ref.watch(catalogRepositoryProvider).series();
  return result.fold(
    onSuccess: (value) => value,
    onFailure: (failure) => throw failure,
  );
});

final movieCategoriesProvider =
    FutureProvider.autoDispose<List<Category>>((ref) async {
  ref.keepAlive();
  final result = await ref.watch(catalogRepositoryProvider).movieCategories();
  return result.fold(onSuccess: (v) => v, onFailure: (f) => throw f);
});

final seriesCategoriesProvider =
    FutureProvider.autoDispose<List<Category>>((ref) async {
  ref.keepAlive();
  final result = await ref.watch(catalogRepositoryProvider).seriesCategories();
  return result.fold(onSuccess: (v) => v, onFailure: (f) => throw f);
});

/// Detail fetches are keyed by id so revisiting a title is instant.
final movieDetailsProvider =
    FutureProvider.autoDispose.family<Movie, Movie>((ref, movie) async {
  final result = await ref.watch(catalogRepositoryProvider).movieDetails(movie);
  return result.fold(onSuccess: (v) => v, onFailure: (f) => throw f);
});

final seriesDetailsProvider =
    FutureProvider.autoDispose.family<Series, Series>((ref, series) async {
  final result =
      await ref.watch(catalogRepositoryProvider).seriesDetails(series);
  return result.fold(onSuccess: (v) => v, onFailure: (f) => throw f);
});

// ------------------------------------------------------------------ filters

class MovieFilterNotifier extends AutoDisposeNotifier<CatalogFilter> {
  @override
  CatalogFilter build() => const CatalogFilter();

  void set(CatalogFilter value) => state = value;
  void query(String value) => state = state.copyWith(query: value);
  void clear() => state = state.cleared();
}

final movieFilterProvider =
    AutoDisposeNotifierProvider<MovieFilterNotifier, CatalogFilter>(
        MovieFilterNotifier.new);

class SeriesFilterNotifier extends AutoDisposeNotifier<CatalogFilter> {
  @override
  CatalogFilter build() => const CatalogFilter();

  void set(CatalogFilter value) => state = value;
  void query(String value) => state = state.copyWith(query: value);
  void clear() => state = state.cleared();
}

final seriesFilterProvider =
    AutoDisposeNotifierProvider<SeriesFilterNotifier, CatalogFilter>(
        SeriesFilterNotifier.new);

/// Filtered + sorted views the grids actually render.
final filteredMoviesProvider = Provider.autoDispose<AsyncValue<List<Movie>>>(
  (ref) {
    final source = ref.watch(moviesProvider);
    final filter = ref.watch(movieFilterProvider);
    final engine = ref.watch(filterCatalogProvider);
    return source.whenData((list) => engine.movies(list, filter));
  },
);

final filteredSeriesProvider = Provider.autoDispose<AsyncValue<List<Series>>>(
  (ref) {
    final source = ref.watch(seriesProvider);
    final filter = ref.watch(seriesFilterProvider);
    final engine = ref.watch(filterCatalogProvider);
    return source.whenData((list) => engine.series(list, filter));
  },
);

/// Distinct genre values, derived from whatever the server actually returned
/// rather than a hardcoded list, so the chips always match the real library.
final movieGenresProvider = Provider.autoDispose<List<String>>((ref) {
  final movies = ref.watch(moviesProvider).valueOrNull ?? const [];
  return _extractGenres(movies.map((m) => m.genre));
});

final seriesGenresProvider = Provider.autoDispose<List<String>>((ref) {
  final series = ref.watch(seriesProvider).valueOrNull ?? const [];
  return _extractGenres(series.map((s) => s.genre));
});

/// A category paired with the titles the server placed in it.
class CategorySection<T> {
  const CategorySection({required this.category, required this.items});
  final Category category;
  final List<T> items;
}

/// Groups the VOD library by the categories the server actually returns.
///
/// Nothing here is hardcoded: if the provider adds "Turkish Movies" tomorrow,
/// it appears on the next catalog refresh without an app update. Categories
/// that come back empty are dropped so the page never shows a blank row.
final movieSectionsProvider =
    Provider.autoDispose<List<CategorySection<Movie>>>((ref) {
  final movies = ref.watch(moviesProvider).valueOrNull ?? const [];
  final categories =
      ref.watch(movieCategoriesProvider).valueOrNull ?? const [];
  return _group<Movie>(categories, movies, (m) => m.categoryId);
});

final seriesSectionsProvider =
    Provider.autoDispose<List<CategorySection<Series>>>((ref) {
  final series = ref.watch(seriesProvider).valueOrNull ?? const [];
  final categories =
      ref.watch(seriesCategoriesProvider).valueOrNull ?? const [];
  return _group<Series>(categories, series, (s) => s.categoryId);
});

List<CategorySection<T>> _group<T>(
  List<Category> categories,
  List<T> items,
  String? Function(T) categoryOf,
) {
  if (items.isEmpty) return const [];

  final buckets = <String, List<T>>{};
  for (final item in items) {
    final key = categoryOf(item);
    if (key == null) continue;
    buckets.putIfAbsent(key, () => <T>[]).add(item);
  }

  final sections = <CategorySection<T>>[];
  for (final category in categories) {
    final bucket = buckets.remove(category.id);
    if (bucket == null || bucket.isEmpty) continue;
    sections.add(CategorySection(category: category, items: bucket));
  }

  // Titles whose category id is missing from the category list would otherwise
  // vanish from the UI entirely, so they get collected into one trailing group.
  final orphans = buckets.values.expand((e) => e).toList();
  if (orphans.isNotEmpty) {
    sections.add(CategorySection(
      category: Category(
        id: '__other__',
        name: 'أخرى',
        kind: sections.isNotEmpty ? sections.first.category.kind : CatalogKind.movies,
      ),
      items: orphans,
    ));
  }
  return sections;
}

List<String> _extractGenres(Iterable<String?> raw) {
  final set = <String>{};
  for (final value in raw) {
    if (value == null || value.isEmpty) continue;
    for (final part in value.split(RegExp(r'[,/|]'))) {
      final trimmed = part.trim();
      if (trimmed.isNotEmpty && trimmed.length < 30) set.add(trimmed);
    }
  }
  final list = set.toList()..sort();
  return list;
}
