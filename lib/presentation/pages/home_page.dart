import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/formatters.dart';
import '../../domain/entities/movie.dart';
import '../../domain/entities/series.dart';
import '../providers/catalog_providers.dart';
import '../widgets/media_card.dart';
import '../widgets/poster_image.dart';
import '../widgets/section_header.dart';
import '../widgets/state_views.dart';
import 'favorites_page.dart';
import 'movie_details_page.dart';
import 'search_page.dart';
import 'series_details_page.dart';

class HomePage extends ConsumerWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final movies = ref.watch(moviesProvider);
    final series = ref.watch(seriesProvider);

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(moviesProvider);
          ref.invalidate(seriesProvider);
          await Future.wait([
            ref.read(moviesProvider.future),
            ref.read(seriesProvider.future),
          ]);
        },
        child: CustomScrollView(
          slivers: [
            SliverAppBar(
              pinned: true,
              // Artwork runs to the very top; the title and icons float over
              // it, so they are forced light regardless of the active theme.
              expandedHeight: 260,
              backgroundColor: AppColors.background,
              foregroundColor: AppColors.onImage,
              iconTheme: const IconThemeData(color: AppColors.onImage),
              systemOverlayStyle: SystemUiOverlayStyle.light,
              flexibleSpace: FlexibleSpaceBar(
                background:
                    _Banner(movies: movies.valueOrNull ?? const []),
                collapseMode: CollapseMode.parallax,
              ),
              title: const Text('مدير التحميل',
                  style: TextStyle(color: AppColors.onImage)),
              actions: [
                IconButton(
                  icon: const Icon(Icons.favorite_border_rounded),
                  tooltip: 'المفضلة',
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                        builder: (_) => const FavoritesPage()),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.search_rounded),
                  tooltip: 'بحث',
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                        builder: (_) => const SearchPage()),
                  ),
                ),
                const SizedBox(width: 4),
              ],
            ),
            if (movies.isLoading && series.isLoading)
              const SliverFillRemaining(
                child: LoadingView(message: 'جارٍ تحميل المكتبة…'),
              )
            else if (movies.hasError && series.hasError)
              SliverFillRemaining(
                child: ErrorView(
                  message: 'تعذّر تحميل المكتبة من الخادم.',
                  onRetry: () {
                    ref.invalidate(moviesProvider);
                    ref.invalidate(seriesProvider);
                  },
                ),
              )
            else ...[
              _MovieRow(
                title: 'أحدث الأفلام',
                movies: _latestMovies(movies.valueOrNull ?? const []),
              ),
              _SeriesRow(
                title: 'أحدث المسلسلات',
                series: _latestSeries(series.valueOrNull ?? const []),
              ),
              _MovieRow(
                title: 'أفلام الأعلى تقييماً',
                movies: _topRated(movies.valueOrNull ?? const []),
              ),
              _SeriesRow(
                title: 'مسلسلات الأعلى تقييماً',
                series: _topRatedSeries(series.valueOrNull ?? const []),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 28)),
            ],
          ],
        ),
      ),
    );
  }

  List<Movie> _latestMovies(List<Movie> source) {
    final list = [...source]
      ..sort((a, b) => (b.addedEpoch ?? 0).compareTo(a.addedEpoch ?? 0));
    return list.take(20).toList();
  }

  List<Series> _latestSeries(List<Series> source) {
    final list = [...source]..sort(
        (a, b) => (b.lastModifiedEpoch ?? 0).compareTo(a.lastModifiedEpoch ?? 0));
    return list.take(20).toList();
  }

  List<Movie> _topRated(List<Movie> source) {
    final list = source.where((m) => (m.rating ?? 0) > 0).toList()
      ..sort((a, b) => (b.rating ?? 0).compareTo(a.rating ?? 0));
    return list.take(20).toList();
  }

  List<Series> _topRatedSeries(List<Series> source) {
    final list = source.where((s) => (s.rating ?? 0) > 0).toList()
      ..sort((a, b) => (b.rating ?? 0).compareTo(a.rating ?? 0));
    return list.take(20).toList();
  }
}

/// Hero banner built from the newest, highest-rated title available.
class _Banner extends StatelessWidget {
  const _Banner({required this.movies});
  final List<Movie> movies;

  @override
  Widget build(BuildContext context) {
    final featured = movies.where((m) => (m.icon ?? '').isNotEmpty).toList()
      ..sort((a, b) => (b.rating ?? 0).compareTo(a.rating ?? 0));
    if (featured.isEmpty) return const SizedBox(height: 8);

    final movie = featured.first;

    return GestureDetector(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute<void>(
            builder: (_) => MovieDetailsPage(movie: movie)),
      ),
      child: SizedBox.expand(
        child: Stack(
          fit: StackFit.expand,
          children: [
            PosterImage(
              url: movie.icon,
              borderRadius: 0,
              memCacheWidth: 900,
            ),
            const DecoratedBox(
              decoration: BoxDecoration(gradient: AppColors.bannerScrim),
            ),
            Positioned(
              right: 18,
              left: 18,
              bottom: 16,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    movie.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    // Sits on the dark scrim, so it is light in both themes.
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      height: 1.3,
                      color: AppColors.onImage,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      if (movie.rating != null && movie.rating! > 0) ...[
                        Icon(Icons.star_rounded,
                            size: 15, color: AppColors.accent),
                        const SizedBox(width: 3),
                        Text(movie.rating!.toStringAsFixed(1),
                            style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: AppColors.onImage)),
                        const SizedBox(width: 12),
                      ],
                      if (Formatters.quality(movie.name) != null)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(
                            border: Border.all(color: AppColors.divider),
                            borderRadius: BorderRadius.circular(5),
                          ),
                          child: Text(
                            Formatters.quality(movie.name)!,
                            style: const TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: AppColors.onImage),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MovieRow extends StatelessWidget {
  const _MovieRow({required this.title, required this.movies});

  final String title;
  final List<Movie> movies;

  @override
  Widget build(BuildContext context) {
    if (movies.isEmpty) return const SliverToBoxAdapter(child: SizedBox());

    return SliverToBoxAdapter(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionHeader(title: title),
          SizedBox(
            height: 190,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: movies.length,
              separatorBuilder: (_, __) => const SizedBox(width: 12),
              itemBuilder: (context, index) {
                final movie = movies[index];
                return MediaCard(
                  width: 100,
                  title: movie.name,
                  posterUrl: movie.icon,
                  rating: movie.rating,
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                        builder: (_) => MovieDetailsPage(movie: movie)),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _SeriesRow extends StatelessWidget {
  const _SeriesRow({required this.title, required this.series});

  final String title;
  final List<Series> series;

  @override
  Widget build(BuildContext context) {
    if (series.isEmpty) return const SliverToBoxAdapter(child: SizedBox());

    return SliverToBoxAdapter(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionHeader(title: title),
          SizedBox(
            height: 190,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: series.length,
              separatorBuilder: (_, __) => const SizedBox(width: 12),
              itemBuilder: (context, index) {
                final item = series[index];
                return MediaCard(
                  width: 100,
                  title: item.name,
                  posterUrl: item.cover,
                  rating: item.rating,
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                        builder: (_) => SeriesDetailsPage(series: item)),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
