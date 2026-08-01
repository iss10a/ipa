import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../domain/entities/category.dart';
import '../../domain/usecases/filter_catalog.dart';

/// Bottom sheet holding sort order plus quality, genre, year and category.
class FilterSheet extends StatefulWidget {
  const FilterSheet({
    super.key,
    required this.initial,
    required this.genres,
    required this.categories,
    this.showQuality = true,
  });

  final CatalogFilter initial;
  final List<String> genres;
  final List<Category> categories;
  final bool showQuality;

  @override
  State<FilterSheet> createState() => _FilterSheetState();

  static Future<CatalogFilter?> show(
    BuildContext context, {
    required CatalogFilter initial,
    required List<String> genres,
    required List<Category> categories,
    bool showQuality = true,
  }) {
    return showModalBottomSheet<CatalogFilter>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => FilterSheet(
        initial: initial,
        genres: genres,
        categories: categories,
        showQuality: showQuality,
      ),
    );
  }
}

class _FilterSheetState extends State<FilterSheet> {
  late CatalogFilter _filter = widget.initial;

  static const _qualities = ['4K', '1080p', '720p'];

  List<String> get _years {
    final current = DateTime.now().year;
    return [for (var y = current; y >= current - 25; y--) '$y'];
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      minChildSize: 0.45,
      maxChildSize: 0.92,
      expand: false,
      builder: (context, controller) => Column(
        children: [
          const SizedBox(height: 10),
          Container(
            width: 38,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.divider,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
            child: Row(
              children: [
                const Text('الترتيب والفلترة',
                    style: TextStyle(
                        fontSize: 17, fontWeight: FontWeight.w800)),
                const Spacer(),
                TextButton(
                  onPressed: () => setState(() => _filter = _filter.cleared()),
                  child: const Text('مسح الكل'),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              controller: controller,
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
              children: [
                _Group(
                  title: 'الترتيب حسب',
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final sort in SortBy.values)
                        ChoiceChip(
                          label: Text(sort.label),
                          selected: _filter.sortBy == sort,
                          onSelected: (_) =>
                              setState(() => _filter = _filter.copyWith(sortBy: sort)),
                        ),
                    ],
                  ),
                ),
                _Group(
                  title: 'الاتجاه',
                  child: Row(
                    children: [
                      Expanded(
                        child: SegmentedButton<bool>(
                          segments: const [
                            ButtonSegment(value: true, label: Text('تنازلي')),
                            ButtonSegment(value: false, label: Text('تصاعدي')),
                          ],
                          selected: {_filter.descending},
                          onSelectionChanged: (value) => setState(
                            () => _filter =
                                _filter.copyWith(descending: value.first),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                if (widget.showQuality)
                  _Group(
                    title: 'الجودة',
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final quality in _qualities)
                          FilterChip(
                            label: Text(quality),
                            selected: _filter.quality == quality,
                            onSelected: (selected) => setState(
                              () => _filter = selected
                                  ? _filter.copyWith(quality: quality)
                                  : _filter.copyWith(clearQuality: true),
                            ),
                          ),
                      ],
                    ),
                  ),
                if (widget.categories.isNotEmpty)
                  _Group(
                    title: 'القسم',
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final category in widget.categories.take(60))
                          FilterChip(
                            label: Text(category.name),
                            selected: _filter.categoryId == category.id,
                            onSelected: (selected) => setState(
                              () => _filter = selected
                                  ? _filter.copyWith(categoryId: category.id)
                                  : _filter.copyWith(clearCategory: true),
                            ),
                          ),
                      ],
                    ),
                  ),
                if (widget.genres.isNotEmpty)
                  _Group(
                    title: 'النوع',
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final genre in widget.genres.take(40))
                          FilterChip(
                            label: Text(genre),
                            selected: _filter.genre == genre,
                            onSelected: (selected) => setState(
                              () => _filter = selected
                                  ? _filter.copyWith(genre: genre)
                                  : _filter.copyWith(clearGenre: true),
                            ),
                          ),
                      ],
                    ),
                  ),
                _Group(
                  title: 'السنة',
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final year in _years)
                        FilterChip(
                          label: Text(year),
                          selected: _filter.year == year,
                          onSelected: (selected) => setState(
                            () => _filter = selected
                                ? _filter.copyWith(year: year)
                                : _filter.copyWith(clearYear: true),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
              child: FilledButton(
                onPressed: () => Navigator.of(context).pop(_filter),
                child: const Text('تطبيق'),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Group extends StatelessWidget {
  const _Group({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textSecondary)),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}
