import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/utils/formatters.dart';
import '../../domain/entities/movie.dart';
import '../../domain/entities/series.dart';
import '../widgets/media_card.dart';
import '../widgets/search_field.dart';
import '../widgets/state_views.dart';
import 'movie_details_page.dart';
import 'series_details_page.dart';

/// Full grid for one server category, opened from a "عرض الكل" link.
/// Kept deliberately simple: the same card, the same grid metrics and the same
/// search field used elsewhere, so it reads as part of the existing app.
class CategoryBrowsePage extends ConsumerStatefulWidget {
  const CategoryBrowsePage.movies({
    super.key,
    required this.title,
    required List<Movie> movies,
  })  : _movies = movies,
        _series = const [];

  const CategoryBrowsePage.series({
    super.key,
    required this.title,
    required List<Series> series,
  })  : _series = series,
        _movies = const [];

  final String title;
  final List<Movie> _movies;
  final List<Series> _series;

  @override
  ConsumerState<CategoryBrowsePage> createState() => _CategoryBrowsePageState();
}

class _CategoryBrowsePageState extends ConsumerState<CategoryBrowsePage> {
  String _query = '';

  bool _matches(String name) {
    if (_query.isEmpty) return true;
    return name.toLowerCase().contains(_query.toLowerCase());
  }

  @override
  Widget build(BuildContext context) {
    final movies = widget._movies.where((m) => _matches(m.name)).toList();
    final series = widget._series.where((s) => _matches(s.name)).toList();
    final count = movies.length + series.length;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(58),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: SearchField(
              hintText: 'ابحث داخل هذا القسم…',
              onChanged: (value) => setState(() => _query = value),
            ),
          ),
        ),
      ),
      body: count == 0
          ? const EmptyView(message: 'لا توجد نتائج مطابقة.')
          : GridView.builder(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
              gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: 108,
                childAspectRatio: 0.54,
                crossAxisSpacing: 12,
                mainAxisSpacing: 16,
              ),
              itemCount: count,
              itemBuilder: (context, index) {
                if (index < movies.length) {
                  final movie = movies[index];
                  return MediaCard(
                    title: movie.name,
                    posterUrl: movie.icon,
                    rating: movie.rating,
                    subtitle:
                        Formatters.year(movie.releaseDate ?? movie.name),
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => MovieDetailsPage(movie: movie),
                      ),
                    ),
                  );
                }
                final item = series[index - movies.length];
                return MediaCard(
                  title: item.name,
                  posterUrl: item.cover,
                  rating: item.rating,
                  subtitle: Formatters.year(item.releaseDate ?? item.name),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => SeriesDetailsPage(series: item),
                    ),
                  ),
                );
              },
            ),
    );
  }
}
