import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';

/// Disk-cached poster with a graceful placeholder. Memory cache is capped so a
/// long scroll through thousands of titles does not balloon RAM.
class PosterImage extends StatelessWidget {
  const PosterImage({
    super.key,
    required this.url,
    this.borderRadius = 12,
    this.fit = BoxFit.cover,
    this.memCacheWidth = 400,
  });

  final String? url;
  final double borderRadius;
  final BoxFit fit;
  final int memCacheWidth;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(borderRadius);

    if (url == null || url!.isEmpty) {
      return ClipRRect(borderRadius: radius, child: const _Fallback());
    }

    return ClipRRect(
      borderRadius: radius,
      child: CachedNetworkImage(
        imageUrl: url!,
        fit: fit,
        memCacheWidth: memCacheWidth,
        fadeInDuration: const Duration(milliseconds: 180),
        placeholder: (_, __) => const _Fallback(shimmer: true),
        errorWidget: (_, __, ___) => const _Fallback(),
      ),
    );
  }
}

class _Fallback extends StatelessWidget {
  const _Fallback({this.shimmer = false});
  final bool shimmer;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.surfaceElevated,
      child: Center(
        child: Icon(
          shimmer ? Icons.image_outlined : Icons.movie_outlined,
          color: AppColors.textTertiary,
          size: 28,
        ),
      ),
    );
  }
}
