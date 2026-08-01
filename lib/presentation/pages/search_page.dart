import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/di/providers.dart';
import '../../domain/entities/movie.dart';
import '../../domain/entities/series.dart';
import '../../domain/usecases/filter_catalog.dart';
import '../providers/catalog_providers.dart';
import '../widgets/media_card.dart';
import '../widgets/search_field.dart';
import '../widgets/state_views.dart';
import 'movie_details_page.dart';
import 'series_details_page.dart';

/// Unified search across both libraries at once.
class SearchPage extends ConsumerStatefulWidget {
  const SearchPage({super.key});

  @override
  ConsumerState<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends ConsumerState<SearchPage> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final movies = ref.watch(moviesProvider).valueOrNull ?? const [];
    final series = ref.watch(seriesProvider).valueOrNull ?? const [];
    final engine = ref.watch(filterCatalogProvider);
    final filter = CatalogFilter(query: _query, sortBy: SortBy.name,
        descending: false);

    // Explicit types: a ternary against `const []` would otherwise widen these
    // to Iterable<dynamic> and silently lose type safety in the builders below.
    final List<Movie> movieHits = _query.isEmpty
        ? const <Movie>[]
        : engine.movies(movies, filter).take(60).toList();
    final List<Series> seriesHits = _query.isEmpty
        ? const <Series>[]
        : engine.series(series, filter).take(60).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('بحث'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(58),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: SearchField(
              autofocus: true,
              hintText: 'ابحث في الأفلام والمسلسلات…',
              onChanged: (value) => setState(() => _query = value),
            ),
          ),
        ),
      ),
      body: _query.isEmpty
          ? const EmptyView(
              message: 'اكتب اسم فيلم أو مسلسل للبحث.',
              icon: Icons.search_rounded,
            )
          : (movieHits.isEmpty && seriesHits.isEmpty)
              ? const EmptyView(message: 'لا توجد نتائج مطابقة.')
              : ListView(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
                  children: [
                    if (movieHits.isNotEmpty) ...[
                      const _Label(text: 'أفلام'),
                      _Grid(
                        count: movieHits.length,
                        builder: (index) {
                          final movie = movieHits[index];
                          return MediaCard(
                            title: movie.name,
                            posterUrl: movie.icon,
                            rating: movie.rating,
                            onTap: () => Navigator.of(context).push(
                              MaterialPageRoute<void>(
                                builder: (_) => MovieDetailsPage(movie: movie),
                              ),
                            ),
                          );
                        },
                      ),
                    ],
                    if (seriesHits.isNotEmpty) ...[
                      const _Label(text: 'مسلسلات'),
                      _Grid(
                        count: seriesHits.length,
                        builder: (index) {
                          final item = seriesHits[index];
                          return MediaCard(
                            title: item.name,
                            posterUrl: item.cover,
                            rating: item.rating,
                            onTap: () => Navigator.of(context).push(
                              MaterialPageRoute<void>(
                                builder: (_) => SeriesDetailsPage(series: item),
                              ),
                            ),
                          );
                        },
                      ),
                    ],
                  ],
                ),
    );
  }
}

class _Label extends StatelessWidget {
  const _Label({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: 12, bottom: 12),
        child: Text(text,
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
      );
}

class _Grid extends StatelessWidget {
  const _Grid({required this.count, required this.builder});

  final int count;
  final Widget Function(int index) builder;

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 108,
        childAspectRatio: 0.54,
        crossAxisSpacing: 12,
        mainAxisSpacing: 16,
      ),
      itemCount: count,
      itemBuilder: (context, index) => builder(index),
    );
  }
}
