import '../../core/utils/result.dart';
import '../../domain/entities/category.dart';
import '../../domain/entities/credentials.dart';
import '../../domain/entities/movie.dart';
import '../../domain/entities/series.dart';
import '../../domain/repositories/catalog_repository.dart';
import '../datasources/local_store.dart';
import '../datasources/xtream_api.dart';
import '../models/xtream_mappers.dart';

/// Reads through a Hive cache so the home screen renders instantly on launch,
/// then refreshes from the network when the cache is stale or forced.
class CatalogRepositoryImpl implements CatalogRepository {
  CatalogRepositoryImpl(this._api, this._local, this._credentials);

  final XtreamApi _api;
  final LocalStore _local;
  final Credentials Function() _credentials;

  @override
  Future<Result<List<Category>>> movieCategories() => guard(() async {
        const key = 'movie_categories';
        final cached = _local.readCatalog(key);
        if (cached is List) {
          return CategoryMapper.listFrom(cached, CatalogKind.movies);
        }
        final raw = await _api.vodCategories(_credentials());
        await _local.writeCatalog(key, raw);
        return CategoryMapper.listFrom(raw, CatalogKind.movies);
      });

  @override
  Future<Result<List<Category>>> seriesCategories() => guard(() async {
        const key = 'series_categories';
        final cached = _local.readCatalog(key);
        if (cached is List) {
          return CategoryMapper.listFrom(cached, CatalogKind.series);
        }
        final raw = await _api.seriesCategories(_credentials());
        await _local.writeCatalog(key, raw);
        return CategoryMapper.listFrom(raw, CatalogKind.series);
      });

  @override
  Future<Result<List<Movie>>> movies({
    String? categoryId,
    bool refresh = false,
  }) =>
      guard(() async {
        final key = 'movies_${categoryId ?? 'all'}';
        if (!refresh) {
          final cached = _local.readCatalog(key);
          if (cached is List) return MovieMapper.listFrom(cached);
        }
        final raw =
            await _api.vodStreams(_credentials(), categoryId: categoryId);
        await _local.writeCatalog(key, raw);
        return MovieMapper.listFrom(raw);
      });

  @override
  Future<Result<List<Series>>> series({
    String? categoryId,
    bool refresh = false,
  }) =>
      guard(() async {
        final key = 'series_${categoryId ?? 'all'}';
        if (!refresh) {
          final cached = _local.readCatalog(key);
          if (cached is List) return SeriesMapper.listFrom(cached);
        }
        final raw =
            await _api.seriesList(_credentials(), categoryId: categoryId);
        await _local.writeCatalog(key, raw);
        return SeriesMapper.listFrom(raw);
      });

  @override
  Future<Result<Movie>> movieDetails(Movie movie) => guard(() async {
        final key = 'vod_info_${movie.streamId}';
        final cached = _local.readCatalog(key);
        if (cached is Map) {
          return movie.mergeDetails(MovieMapper.detailsFrom(cached, movie));
        }
        final raw = await _api.vodInfo(_credentials(), movie.streamId);
        await _local.writeCatalog(key, raw);
        return movie.mergeDetails(MovieMapper.detailsFrom(raw, movie));
      });

  @override
  Future<Result<Series>> seriesDetails(Series series) => guard(() async {
        final key = 'series_info_${series.seriesId}';
        final cached = _local.readCatalog(key);
        if (cached is Map) {
          return series.withSeasons(SeriesMapper.seasonsFrom(cached));
        }
        final raw = await _api.seriesInfo(_credentials(), series.seriesId);
        await _local.writeCatalog(key, raw);
        return series.withSeasons(SeriesMapper.seasonsFrom(raw));
      });

  @override
  Future<void> clearCache() => _local.clearCatalog();
}
