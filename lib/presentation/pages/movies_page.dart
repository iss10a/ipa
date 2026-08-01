import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/utils/formatters.dart';
import '../../domain/entities/movie.dart';
import '../providers/catalog_providers.dart';
import '../widgets/filter_sheet.dart';
import '../widgets/media_card.dart';
import '../widgets/search_field.dart';
import '../widgets/section_header.dart';
import '../widgets/state_views.dart';
import 'category_browse_page.dart';
import 'movie_details_page.dart';

/// Films browsed by the categories the server defines.
///
/// The flat grid is still used, but only while a search or filter is active.
/// With neither, the page is a vertical stack of one horizontal row per
/// category, which keeps a library of tens of thousands of titles navigable.
class MoviesPage extends ConsumerWidget {
  const MoviesPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filter = ref.watch(movieFilterProvider);
    final isBrowsing = filter.query.isEmpty && !filter.isActive;
    final source = ref.watch(moviesProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('الأفلام'),
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
                genres: ref.read(movieGenresProvider),
                categories:
                    ref.read(movieCategoriesProvider).valueOrNull ?? const [],
              );
              if (result != null) {
                ref.read(movieFilterProvider.notifier).set(result);
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
              hintText: 'ابحث في الأفلام…',
              initialValue: filter.query,
              onChanged: (value) =>
                  ref.read(movieFilterProvider.notifier).query(value),
            ),
          ),
        ),
      ),
      body: source.when(
        loading: () => const LoadingView(message: 'جارٍ تحميل الأفلام…'),
        error: (error, _) => ErrorView(
          message: 'تعذّر تحميل قائمة الأفلام.',
          onRetry: () => ref.invalidate(moviesProvider),
        ),
        data: (_) => RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(moviesProvider);
            ref.invalidate(movieCategoriesProvider);
            await ref.read(moviesProvider.future);
          },
          child: isBrowsing
              ? const _CategorySections()
              : const _FlatResults(),
        ),
      ),
    );
  }
}

class _CategorySections extends ConsumerWidget {
  const _CategorySections();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sections = ref.watch(movieSectionsProvider);

    if (sections.isEmpty) {
      return const EmptyView(
        message: 'لم يُرجع الخادم أي تصنيفات للأفلام.',
        icon: Icons.movie_filter_outlined,
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 28),
      itemCount: sections.length,
      itemBuilder: (context, index) {
        final section = sections[index];
        // Only a slice is rendered per row; the full list stays one tap away.
        final preview = section.items.take(20).toList();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SectionHeader(
              title: '${section.category.name} (${section.items.length})',
              onSeeAll: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => CategoryBrowsePage.movies(
                    title: section.category.name,
                    movies: section.items,
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
                  final movie = preview[i];
                  return MediaCard(
                    width: 100,
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
    final movies = ref.watch(filteredMoviesProvider);

    return movies.when(
      loading: () => const LoadingView(),
      error: (_, __) => const ErrorView(message: 'تعذّر عرض النتائج.'),
      data: (list) {
        if (list.isEmpty) {
          return const EmptyView(
            message: 'لا توجد أفلام مطابقة.',
            icon: Icons.movie_filter_outlined,
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
            final Movie movie = list[index];
            return MediaCard(
              title: movie.name,
              posterUrl: movie.icon,
              rating: movie.rating,
              subtitle: Formatters.year(movie.releaseDate ?? movie.name),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => MovieDetailsPage(movie: movie),
                ),
              ),
            );
          },
        );
      },
    );
  }
}
