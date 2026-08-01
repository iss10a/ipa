import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/utils/formatters.dart';
import '../../domain/entities/series.dart';
import '../providers/catalog_providers.dart';
import '../widgets/filter_sheet.dart';
import '../widgets/media_card.dart';
import '../widgets/search_field.dart';
import '../widgets/section_header.dart';
import '../widgets/state_views.dart';
import 'category_browse_page.dart';
import 'series_details_page.dart';

/// Series browsed by the categories the server defines. Mirrors MoviesPage so
/// the two tabs behave identically.
class SeriesPage extends ConsumerWidget {
  const SeriesPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filter = ref.watch(seriesFilterProvider);
    final isBrowsing = filter.query.isEmpty && !filter.isActive;
    final source = ref.watch(seriesProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('المسلسلات'),
        actions: [
          IconButton(
            icon: Badge(
              isLabelVisible: filter.isActive,
              label: Text('${filter.activeCount}'),
              child: const Icon(Icons.tune_rounded),
            ),
            tooltip: 'ترتيب وفلترة',
            onPressed: () async {
              final result = await FilterSheet.show(
                context,
                initial: filter,
                genres: ref.read(seriesGenresProvider),
                categories:
                    ref.read(seriesCategoriesProvider).valueOrNull ?? const [],
                showQuality: false,
              );
              if (result != null) {
                ref.read(seriesFilterProvider.notifier).set(result);
              }
            },
          ),
          const SizedBox(width: 4),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(58),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: SearchField(
              hintText: 'ابحث في المسلسلات…',
              initialValue: filter.query,
              onChanged: (value) =>
                  ref.read(seriesFilterProvider.notifier).query(value),
            ),
          ),
        ),
      ),
      body: source.when(
        loading: () => const LoadingView(message: 'جارٍ تحميل المسلسلات…'),
        error: (error, _) => ErrorView(
          message: 'تعذّر تحميل قائمة المسلسلات.',
          onRetry: () => ref.invalidate(seriesProvider),
        ),
        data: (_) => RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(seriesProvider);
            ref.invalidate(seriesCategoriesProvider);
            await ref.read(seriesProvider.future);
          },
          child:
              isBrowsing ? const _CategorySections() : const _FlatResults(),
        ),
      ),
    );
  }
}

class _CategorySections extends ConsumerWidget {
  const _CategorySections();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sections = ref.watch(seriesSectionsProvider);

    if (sections.isEmpty) {
      return const EmptyView(
        message: 'لم يُرجع الخادم أي تصنيفات للمسلسلات.',
        icon: Icons.tv_off_outlined,
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 28),
      itemCount: sections.length,
      itemBuilder: (context, index) {
        final section = sections[index];
        final preview = section.items.take(20).toList();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SectionHeader(
              title: '${section.category.name} (${section.items.length})',
              onSeeAll: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => CategoryBrowsePage.series(
                    title: section.category.name,
                    series: section.items,
                  ),
                ),
              ),
            ),
            SizedBox(
              height: 190,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: preview.length,
                separatorBuilder: (_, __) => const SizedBox(width: 12),
                itemBuilder: (context, i) {
                  final item = preview[i];
                  return MediaCard(
                    width: 100,
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
            ),
          ],
        );
      },
    );
  }
}

class _FlatResults extends ConsumerWidget {
  const _FlatResults();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final series = ref.watch(filteredSeriesProvider);

    return series.when(
      loading: () => const LoadingView(),
      error: (_, __) => const ErrorView(message: 'تعذّر عرض النتائج.'),
      data: (list) {
        if (list.isEmpty) {
          return const EmptyView(
            message: 'لا توجد مسلسلات مطابقة.',
            icon: Icons.tv_off_outlined,
          );
        }
        return GridView.builder(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
          gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
            maxCrossAxisExtent: 108,
            childAspectRatio: 0.54,
            crossAxisSpacing: 12,
            mainAxisSpacing: 16,
          ),
          itemCount: list.length,
          itemBuilder: (context, index) {
            final Series item = list[index];
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
        );
      },
    );
  }
}
