import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/di/providers.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/formatters.dart';
import '../../domain/entities/download_task.dart';
import '../../domain/entities/movie.dart';
import '../providers/catalog_providers.dart';
import '../widgets/favorite_button.dart';
import '../widgets/poster_image.dart';
import '../widgets/state_views.dart';

class MovieDetailsPage extends ConsumerWidget {
  const MovieDetailsPage({super.key, required this.movie});

  final Movie movie;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final details = ref.watch(movieDetailsProvider(movie));
    final resolved = details.valueOrNull ?? movie;

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 230,
            pinned: true,
            actions: [
              FavoriteButton.movie(resolved),
              const SizedBox(width: 4),
            ],
            flexibleSpace: FlexibleSpaceBar(
              background: Stack(
                fit: StackFit.expand,
                children: [
                  PosterImage(
                    url: resolved.icon,
                    borderRadius: 0,
                    memCacheWidth: 900,
                  ),
                  const DecoratedBox(
                    decoration:
                        BoxDecoration(gradient: AppColors.bannerScrim),
                  ),
                ],
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                Text(
                  resolved.name,
                  style: const TextStyle(
                      fontSize: 21, fontWeight: FontWeight.w800, height: 1.35),
                ),
                const SizedBox(height: 14),
                _MetaRow(movie: resolved),
                const SizedBox(height: 22),
                _DownloadButton(movie: resolved),
                if (details.isLoading) ...[
                  const SizedBox(height: 30),
                  const LoadingView(message: 'جارٍ تحميل التفاصيل…'),
                ],
                if (resolved.plot != null) ...[
                  const SizedBox(height: 28),
                  const _Heading(text: 'القصة'),
                  const SizedBox(height: 8),
                  Text(
                    resolved.plot!,
                    style: TextStyle(
                        fontSize: 14, height: 1.8,
                        color: AppColors.textSecondary),
                  ),
                ],
                if (resolved.cast != null) ...[
                  const SizedBox(height: 24),
                  const _Heading(text: 'الأبطال'),
                  const SizedBox(height: 8),
                  Text(resolved.cast!,
                      style: TextStyle(
                          fontSize: 13, height: 1.8,
                          color: AppColors.textSecondary)),
                ],
                if (resolved.director != null) ...[
                  const SizedBox(height: 24),
                  const _Heading(text: 'الإخراج'),
                  const SizedBox(height: 8),
                  Text(resolved.director!,
                      style: TextStyle(
                          fontSize: 13, color: AppColors.textSecondary)),
                ],
              ]),
            ),
          ),
        ],
      ),
    );
  }
}

class _MetaRow extends StatelessWidget {
  const _MetaRow({required this.movie});
  final Movie movie;

  @override
  Widget build(BuildContext context) {
    final chips = <Widget>[
      if (movie.rating != null && movie.rating! > 0)
        _Chip(
          icon: Icons.star_rounded,
          text: movie.rating!.toStringAsFixed(1),
        ),
      if (Formatters.year(movie.releaseDate ?? movie.name) != null)
        _Chip(text: Formatters.year(movie.releaseDate ?? movie.name)!),
      if (Formatters.quality(movie.name) != null)
        _Chip(text: Formatters.quality(movie.name)!),
      if (movie.durationSeconds != null && movie.durationSeconds! > 0)
        _Chip(text: Formatters.duration(movie.durationSeconds!)),
      if (movie.genre != null) _Chip(text: movie.genre!),
      _Chip(text: movie.containerExtension.toUpperCase()),
    ];

    return Wrap(spacing: 8, runSpacing: 8, children: chips);
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.text, this.icon});

  final String text;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 13, color: AppColors.accent),
            const SizedBox(width: 4),
          ],
          Text(text,
              style: const TextStyle(
                  fontSize: 12, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

class _Heading extends StatelessWidget {
  const _Heading({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) => Text(
        text,
        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
      );
}

class _DownloadButton extends ConsumerWidget {
  const _DownloadButton({required this.movie});
  final Movie movie;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final queue = ref.watch(downloadQueueProvider);

    return AnimatedBuilder(
      animation: queue,
      builder: (context, _) {
        final existing = queue.itemById('movie:${movie.streamId}');

        if (existing != null &&
            existing.status == DownloadStatus.completed) {
          return OutlinedButton.icon(
            onPressed: null,
            icon: Icon(Icons.check_circle_rounded,
                size: 20, color: AppColors.success),
            label: const Text('تم التحميل'),
          );
        }

        if (existing != null && !existing.status.isTerminal) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              OutlinedButton.icon(
                onPressed: null,
                icon: const Icon(Icons.downloading_rounded, size: 20),
                label: Text(existing.status == DownloadStatus.running
                    ? 'جارٍ التحميل ${Formatters.percent(existing.progress)}'
                    : existing.status.label),
              ),
              if (existing.totalBytes > 0) ...[
                const SizedBox(height: 10),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: existing.progress,
                    minHeight: 4,
                  ),
                ),
              ],
            ],
          );
        }

        return FilledButton.icon(
          onPressed: () async {
            final session = ref.read(sessionProvider);
            if (session == null) return;

            final item = ref.read(buildDownloadItemsProvider).forMovie(
                  movie: movie,
                  credentials: session,
                  settings: ref.read(settingsProvider),
                );
            final outcome = await queue.enqueue(item);

            if (!context.mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(outcome.message)),
            );
          },
          icon: const Icon(Icons.download_rounded, size: 20),
          label: const Text('تحميل'),
        );
      },
    );
  }
}
