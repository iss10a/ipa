import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../domain/entities/favorite.dart';
import '../providers/favorites_providers.dart';
import '../widgets/media_card.dart';
import '../widgets/section_header.dart';
import '../widgets/state_views.dart';
import 'movie_details_page.dart';
import 'series_details_page.dart';

/// Standalone favourites screen. Films and series are shown in two sections
/// using the same poster card as the rest of the app.
class FavoritesPage extends ConsumerWidget {
  const FavoritesPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final favorites = ref.watch(favoritesProvider);
    final movies =
        favorites.where((f) => f.kind == FavoriteKind.movie).toList();
    final series =
        favorites.where((f) => f.kind == FavoriteKind.series).toList();

    return Scaffold(
      appBar: AppBar(title: const Text('المفضلة')),
      body: favorites.isEmpty
          ? const EmptyView(
              message: 'لا توجد عناصر في المفضلة.\n'
                  'اضغط على ♥ في صفحة أي فيلم أو مسلسل لإضافته.',
              icon: Icons.favorite_border_rounded,
            )
          : ListView(
              padding: const EdgeInsets.only(bottom: 28),
              children: [
                if (movies.isNotEmpty) ...[
                  const SectionHeader(title: 'أفلام'),
                  _Grid(items: movies),
                ],
                if (series.isNotEmpty) ...[
                  const SectionHeader(title: 'مسلسلات'),
                  _Grid(items: series),
                ],
              ],
            ),
    );
  }
}

class _Grid extends ConsumerWidget {
  const _Grid({required this.items});

  final List<FavoriteItem> items;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 108,
        childAspectRatio: 0.54,
        crossAxisSpacing: 12,
        mainAxisSpacing: 16,
      ),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];
        return Stack(
          children: [
            MediaCard(
              title: item.name,
              posterUrl: item.posterUrl,
              rating: item.rating,
              onTap: () {
                final route = item.kind == FavoriteKind.movie
                    ? MaterialPageRoute<void>(
                        builder: (_) =>
                            MovieDetailsPage(movie: movieFromFavorite(item)),
                      )
                    : MaterialPageRoute<void>(
                        builder: (_) =>
                            SeriesDetailsPage(series: seriesFromFavorite(item)),
                      );
                Navigator.of(context).push(route);
              },
            ),
            // Removing from here updates the list immediately, since the grid
            // is driven by the same notifier state.
            Positioned(
              top: 0,
              left: 0,
              child: Material(
                color: Colors.black45,
                shape: const CircleBorder(),
                child: InkWell(
                  customBorder: const CircleBorder(),
                  onTap: () =>
                      ref.read(favoritesProvider.notifier).remove(item.id),
                  child: const Padding(
                    padding: EdgeInsets.all(5),
                    child: Icon(Icons.close_rounded,
                        size: 14, color: AppColors.onImage),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
