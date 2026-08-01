import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/di/providers.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/formatters.dart';
import '../../domain/entities/download_task.dart';
import '../../domain/entities/episode.dart';
import '../../domain/entities/season.dart';
import '../../domain/entities/series.dart';
import '../providers/catalog_providers.dart';
import '../widgets/favorite_button.dart';
import '../widgets/poster_image.dart';
import '../widgets/state_views.dart';

class SeriesDetailsPage extends ConsumerWidget {
  const SeriesDetailsPage({super.key, required this.series});

  final Series series;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final details = ref.watch(seriesDetailsProvider(series));

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 210,
            pinned: true,
            actions: [
              FavoriteButton.series(series),
              const SizedBox(width: 4),
            ],
            flexibleSpace: FlexibleSpaceBar(
              background: Stack(
                fit: StackFit.expand,
                children: [
                  PosterImage(
                      url: series.cover, borderRadius: 0, memCacheWidth: 900),
                  const DecoratedBox(
                    decoration:
                        BoxDecoration(gradient: AppColors.bannerScrim),
                  ),
                ],
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
            sliver: SliverToBoxAdapter(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    series.name,
                    style: const TextStyle(
                        fontSize: 21,
                        fontWeight: FontWeight.w800,
                        height: 1.35),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      if (series.rating != null && series.rating! > 0)
                        _Chip(
                            icon: Icons.star_rounded,
                            text: series.rating!.toStringAsFixed(1)),
                      if (Formatters.year(series.releaseDate ?? '') != null)
                        _Chip(
                            text: Formatters.year(series.releaseDate ?? '')!),
                      if (series.genre != null) _Chip(text: series.genre!),
                    ],
                  ),
                  if (series.plot != null) ...[
                    const SizedBox(height: 18),
                    Text(
                      series.plot!,
                      style: TextStyle(
                          fontSize: 13,
                          height: 1.8,
                          color: AppColors.textSecondary),
                    ),
                  ],
                ],
              ),
            ),
          ),
          details.when(
            loading: () => const SliverFillRemaining(
              hasScrollBody: false,
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 60),
                child: LoadingView(message: 'جارٍ تحميل المواسم…'),
              ),
            ),
            error: (error, _) => SliverFillRemaining(
              hasScrollBody: false,
              child: ErrorView(
                message: 'تعذّر تحميل مواسم هذا المسلسل.',
                onRetry: () => ref.invalidate(seriesDetailsProvider(series)),
              ),
            ),
            data: (resolved) {
              if (resolved.seasons.isEmpty) {
                return const SliverFillRemaining(
                  hasScrollBody: false,
                  child: EmptyView(
                    message: 'لا توجد حلقات متاحة لهذا المسلسل.',
                    icon: Icons.playlist_remove_rounded,
                  ),
                );
              }
              return SliverPadding(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 40),
                sliver: SliverList.builder(
                  itemCount: resolved.seasons.length,
                  itemBuilder: (context, index) => _SeasonTile(
                    series: resolved,
                    season: resolved.seasons[index],
                    initiallyExpanded: index == 0,
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _SeasonTile extends ConsumerWidget {
  const _SeasonTile({
    required this.series,
    required this.season,
    required this.initiallyExpanded,
  });

  final Series series;
  final Season season;
  final bool initiallyExpanded;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final queue = ref.watch(downloadQueueProvider);

    return AnimatedBuilder(
      animation: queue,
      builder: (context, _) {
        final queuedCount = season.episodes
            .where((e) => queue.itemById('episode:${e.id}') != null)
            .length;

        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: Theme(
            data: Theme.of(context)
                .copyWith(dividerColor: Colors.transparent),
            child: ExpansionTile(
              initiallyExpanded: initiallyExpanded,
              tilePadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              title: Text(
                season.displayName,
                style: const TextStyle(
                    fontSize: 15, fontWeight: FontWeight.w700),
              ),
              subtitle: Padding(
                padding: const EdgeInsets.only(top: 3),
                child: Text(
                  queuedCount == 0
                      ? '${season.episodes.length} حلقة'
                      : '${season.episodes.length} حلقة · '
                          '$queuedCount في القائمة',
                  style: TextStyle(
                      fontSize: 12, color: AppColors.textTertiary),
                ),
              ),
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(44),
                    ),
                    onPressed: () => _downloadSeason(context, ref),
                    icon: const Icon(Icons.playlist_add_rounded, size: 20),
                    label: const Text('تحميل الموسم كاملاً'),
                  ),
                ),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  child: Text(
                    'تُضاف كل الحلقات إلى القائمة وتُحمَّل واحدة تلو الأخرى '
                    'بالترتيب.',
                    style: TextStyle(
                        fontSize: 11,
                        height: 1.6,
                        color: AppColors.textTertiary),
                  ),
                ),
                const SizedBox(height: 8),
                for (final episode in season.episodes)
                  _EpisodeTile(series: series, episode: episode),
                const SizedBox(height: 8),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _downloadSeason(BuildContext context, WidgetRef ref) async {
    final session = ref.read(sessionProvider);
    if (session == null) return;

    final items = ref.read(buildDownloadItemsProvider).forSeason(
          series: series,
          season: season,
          credentials: session,
          settings: ref.read(settingsProvider),
        );

    final added =
        await ref.read(downloadQueueProvider).enqueueBatch(items);

    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(added == 0
            ? 'كل حلقات هذا الموسم موجودة مسبقاً'
            : 'أُضيفت $added حلقة إلى القائمة'),
      ),
    );
  }
}

class _EpisodeTile extends ConsumerWidget {
  const _EpisodeTile({required this.series, required this.episode});

  final Series series;
  final Episode episode;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final queue = ref.watch(downloadQueueProvider);

    return AnimatedBuilder(
      animation: queue,
      builder: (context, _) {
        final existing = queue.itemById('episode:${episode.id}');

        return ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 16),
          dense: true,
          leading: SizedBox(
            width: 34,
            child: Center(
              child: Text(
                episode.episodeNumber.toString().padLeft(2, '0'),
                style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textTertiary),
              ),
            ),
          ),
          title: Text(
            episode.title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 13, height: 1.4),
          ),
          subtitle: episode.durationSeconds == null
              ? null
              : Text(
                  Formatters.duration(episode.durationSeconds!),
                  style: TextStyle(
                      fontSize: 11, color: AppColors.textTertiary),
                ),
          trailing: _EpisodeAction(
            status: existing?.status,
            progress: existing?.progress ?? 0,
            onDownload: () async {
              final session = ref.read(sessionProvider);
              if (session == null) return;

              final item = ref.read(buildDownloadItemsProvider).forEpisode(
                    series: series,
                    episode: episode,
                    credentials: session,
                    settings: ref.read(settingsProvider),
                  );
              final outcome = await queue.enqueue(item);

              if (!context.mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(outcome.message)),
              );
            },
          ),
        );
      },
    );
  }
}

class _EpisodeAction extends StatelessWidget {
  const _EpisodeAction({
    required this.status,
    required this.progress,
    required this.onDownload,
  });

  final DownloadStatus? status;
  final double progress;
  final VoidCallback onDownload;

  @override
  Widget build(BuildContext context) {
    if (status == DownloadStatus.completed) {
      return Icon(Icons.check_circle_rounded,
          size: 22, color: AppColors.success);
    }
    if (status == DownloadStatus.running) {
      return SizedBox(
        width: 22,
        height: 22,
        child: CircularProgressIndicator(
          strokeWidth: 2.4,
          value: progress > 0 ? progress : null,
        ),
      );
    }
    if (status == DownloadStatus.queued) {
      return Icon(Icons.schedule_rounded,
          size: 20, color: AppColors.textTertiary);
    }
    if (status == DownloadStatus.paused) {
      return Icon(Icons.pause_circle_outline_rounded,
          size: 22, color: AppColors.warning);
    }

    return IconButton(
      icon: const Icon(Icons.download_rounded, size: 20),
      color: AppColors.accent,
      tooltip: 'تحميل',
      onPressed: onDownload,
    );
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
              style:
                  const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}
