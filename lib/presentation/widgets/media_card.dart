import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/formatters.dart';
import 'poster_image.dart';

/// Poster tile used by every grid and carousel.
class MediaCard extends StatelessWidget {
  const MediaCard({
    super.key,
    required this.title,
    required this.posterUrl,
    required this.onTap,
    this.rating,
    this.subtitle,
    this.width,
    this.badge,
  });

  final String title;
  final String? posterUrl;
  final VoidCallback onTap;
  final double? rating;
  final String? subtitle;
  final double? width;
  final String? badge;

  @override
  Widget build(BuildContext context) {
    final quality = badge ?? Formatters.quality(title);

    return SizedBox(
      width: width,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            AspectRatio(
              aspectRatio: 2 / 3,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  PosterImage(url: posterUrl),
                  if (quality != null)
                    Positioned(
                      top: 6,
                      right: 6,
                      child: _Pill(text: quality, color: AppColors.accent),
                    ),
                  if (rating != null && rating! > 0)
                    Positioned(
                      bottom: 6,
                      left: 6,
                      child: _Pill(
                        text: rating!.toStringAsFixed(1),
                        color: AppColors.surface,
                        icon: Icons.star_rounded,
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                height: 1.35,
              ),
            ),
            if (subtitle != null)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(
                  subtitle!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      fontSize: 11, color: AppColors.textTertiary),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.text, required this.color, this.icon});

  final String text;
  final Color color;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final onColor =
        color == AppColors.accent ? AppColors.white : AppColors.accent;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: color == AppColors.accent ? 1 : 0.9),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 11, color: onColor),
            const SizedBox(width: 2),
          ],
          Text(
            text,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              color: onColor,
            ),
          ),
        ],
      ),
    );
  }
}
