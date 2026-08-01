import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../domain/entities/favorite.dart';
import '../../domain/entities/movie.dart';
import '../../domain/entities/series.dart';
import '../providers/favorites_providers.dart';

/// Heart toggle. Uses the existing accent colour when active so it reads as
/// part of the current design rather than a bolted-on control.
class FavoriteButton extends ConsumerWidget {
  const FavoriteButton.movie(this.movie, {super.key, this.size = 22})
      : series = null;

  const FavoriteButton.series(this.series, {super.key, this.size = 22})
      : movie = null;

  final Movie? movie;
  final Series? series;
  final double size;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final id = movie != null
        ? FavoriteItem.movieId(movie!.streamId)
        : FavoriteItem.seriesId(series!.seriesId);

    final isFavorite = ref.watch(isFavoriteProvider(id));

    return IconButton(
      tooltip: isFavorite ? 'إزالة من المفضلة' : 'إضافة إلى المفضلة',
      icon: Icon(
        isFavorite ? Icons.favorite_rounded : Icons.favorite_border_rounded,
        size: size,
        color: isFavorite ? AppColors.danger : AppColors.textSecondary,
      ),
      onPressed: () {
        final notifier = ref.read(favoritesProvider.notifier);
        if (movie != null) {
          notifier.toggleMovie(movie!);
        } else {
          notifier.toggleSeries(series!);
        }
      },
    );
  }
}
