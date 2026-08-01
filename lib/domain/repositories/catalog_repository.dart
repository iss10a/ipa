import '../entities/category.dart';
import '../entities/movie.dart';
import '../entities/series.dart';
import '../../core/utils/result.dart';

abstract interface class CatalogRepository {
  Future<Result<List<Category>>> movieCategories();
  Future<Result<List<Category>>> seriesCategories();

  /// Full VOD list, optionally narrowed to one category.
  Future<Result<List<Movie>>> movies({String? categoryId, bool refresh = false});

  /// Full series list, optionally narrowed to one category.
  Future<Result<List<Series>>> series({String? categoryId, bool refresh = false});

  /// Enriches a movie with plot, cast, genre and duration.
  Future<Result<Movie>> movieDetails(Movie movie);

  /// Loads seasons and episodes for a series.
  Future<Result<Series>> seriesDetails(Series series);

  Future<void> clearCache();
}
