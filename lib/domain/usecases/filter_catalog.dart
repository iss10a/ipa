import '../../core/utils/formatters.dart';
import '../entities/movie.dart';
import '../entities/series.dart';

enum SortBy { name, year, dateAdded, rating }

extension SortByX on SortBy {
  String get label => switch (this) {
        SortBy.name => 'الاسم',
        SortBy.year => 'السنة',
        SortBy.dateAdded => 'تاريخ الإضافة',
        SortBy.rating => 'التقييم',
      };
}

/// Free-form filter state shared by the movies and series screens.
class CatalogFilter {
  const CatalogFilter({
    this.query = '',
    this.sortBy = SortBy.dateAdded,
    this.descending = true,
    this.quality,
    this.genre,
    this.year,
    this.categoryId,
  });

  final String query;
  final SortBy sortBy;
  final bool descending;

  /// '4K' | '1080p' | '720p'
  final String? quality;
  final String? genre;
  final String? year;
  final String? categoryId;

  bool get isActive =>
      quality != null || genre != null || year != null || categoryId != null;

  int get activeCount => [quality, genre, year, categoryId]
      .where((v) => v != null)
      .length;

  CatalogFilter copyWith({
    String? query,
    SortBy? sortBy,
    bool? descending,
    String? quality,
    String? genre,
    String? year,
    String? categoryId,
    bool clearQuality = false,
    bool clearGenre = false,
    bool clearYear = false,
    bool clearCategory = false,
  }) =>
      CatalogFilter(
        query: query ?? this.query,
        sortBy: sortBy ?? this.sortBy,
        descending: descending ?? this.descending,
        quality: clearQuality ? null : (quality ?? this.quality),
        genre: clearGenre ? null : (genre ?? this.genre),
        year: clearYear ? null : (year ?? this.year),
        categoryId: clearCategory ? null : (categoryId ?? this.categoryId),
      );

  CatalogFilter cleared() => CatalogFilter(query: query, sortBy: sortBy,
      descending: descending);
}

/// Case- and diacritic-tolerant matching so Arabic titles search naturally.
String normalizeArabic(String input) {
  var out = input.toLowerCase().trim();
  out = out.replaceAll(RegExp(r'[\u064B-\u0652\u0670\u0640]'), '');
  out = out.replaceAll(RegExp('[أإآٱ]'), 'ا');
  out = out.replaceAll('ى', 'ي');
  out = out.replaceAll('ة', 'ه');
  out = out.replaceAll('ؤ', 'و');
  out = out.replaceAll('ئ', 'ي');
  out = out.replaceAll(RegExp(r'\s+'), ' ');
  return out;
}

class FilterCatalog {
  const FilterCatalog();

  List<Movie> movies(List<Movie> source, CatalogFilter filter) {
    final query = normalizeArabic(filter.query);
    final out = source.where((m) {
      if (filter.categoryId != null && m.categoryId != filter.categoryId) {
        return false;
      }
      if (query.isNotEmpty && !normalizeArabic(m.name).contains(query)) {
        return false;
      }
      if (filter.quality != null &&
          Formatters.quality(m.name) != filter.quality) {
        return false;
      }
      if (filter.year != null &&
          Formatters.year(m.releaseDate ?? m.name) != filter.year) {
        return false;
      }
      if (filter.genre != null &&
          !(m.genre ?? '').contains(filter.genre!)) {
        return false;
      }
      return true;
    }).toList();

    out.sort((a, b) {
      final result = switch (filter.sortBy) {
        SortBy.name => a.name.compareTo(b.name),
        SortBy.rating => (a.rating ?? 0).compareTo(b.rating ?? 0),
        SortBy.year => (Formatters.year(a.releaseDate ?? a.name) ?? '')
            .compareTo(Formatters.year(b.releaseDate ?? b.name) ?? ''),
        SortBy.dateAdded => (a.addedEpoch ?? 0).compareTo(b.addedEpoch ?? 0),
      };
      return filter.descending ? -result : result;
    });

    return out;
  }

  List<Series> series(List<Series> source, CatalogFilter filter) {
    final query = normalizeArabic(filter.query);
    final out = source.where((s) {
      if (filter.categoryId != null && s.categoryId != filter.categoryId) {
        return false;
      }
      if (query.isNotEmpty && !normalizeArabic(s.name).contains(query)) {
        return false;
      }
      if (filter.year != null &&
          Formatters.year(s.releaseDate ?? s.name) != filter.year) {
        return false;
      }
      if (filter.genre != null && !(s.genre ?? '').contains(filter.genre!)) {
        return false;
      }
      return true;
    }).toList();

    out.sort((a, b) {
      final result = switch (filter.sortBy) {
        SortBy.name => a.name.compareTo(b.name),
        SortBy.rating => (a.rating ?? 0).compareTo(b.rating ?? 0),
        SortBy.year => (Formatters.year(a.releaseDate ?? a.name) ?? '')
            .compareTo(Formatters.year(b.releaseDate ?? b.name) ?? ''),
        SortBy.dateAdded =>
          (a.lastModifiedEpoch ?? 0).compareTo(b.lastModifiedEpoch ?? 0),
      };
      return filter.descending ? -result : result;
    });

    return out;
  }
}
