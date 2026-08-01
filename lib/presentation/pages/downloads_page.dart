import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gal/gal.dart';

import '../../core/constants/app_constants.dart';
import '../../core/di/providers.dart';
import '../../core/theme/app_colors.dart';
import '../../domain/entities/download_task.dart';
import '../../downloader/download_queue_manager.dart';
import '../widgets/download_progress.dart';
import '../widgets/state_views.dart';
import 'player_page.dart';

/// The downloads library.
///
/// Raw files are never shown. Films appear as titles; series appear as titles
/// that open onto seasons and then episodes. Deleting a title removes its whole
/// folder, so nothing is orphaned on disk.
class DownloadsPage extends ConsumerStatefulWidget {
  const DownloadsPage({super.key});

  @override
  ConsumerState<DownloadsPage> createState() => _DownloadsPageState();
}

class _DownloadsPageState extends ConsumerState<DownloadsPage> {
  final Set<String> _selected = {};
  bool _selectionMode = false;

  void _toggle(String id) {
    setState(() {
      if (!_selected.remove(id)) _selected.add(id);
      _selectionMode = _selected.isNotEmpty;
    });
  }

  void _exitSelection() {
    setState(() {
      _selected.clear();
      _selectionMode = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final queue = ref.watch(downloadQueueProvider);

    return AnimatedBuilder(
      animation: queue,
      builder: (context, _) {
        final items = queue.items;

        // Drop ids that no longer exist so selection can never go stale.
        _selected.removeWhere((id) => queue.itemById(id) == null);

        return Scaffold(
          appBar: _selectionMode
              ? _selectionAppBar(queue, items)
              : _defaultAppBar(queue),
          body: items.isEmpty
              ? const EmptyView(
                  message: 'لا توجد تحميلات بعد.\n'
                      'اختر فيلماً أو مسلسلاً وابدأ التحميل.',
                  icon: Icons.download_outlined,
                )
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(12, 12, 12, 28),
                  itemCount: items.length,
                  itemBuilder: (context, index) {
                    final item = items[index];
                    return _DownloadRow(
                      item: item,
                      queue: queue,
                      selected: _selected.contains(item.id),
                      selectionMode: _selectionMode,
                      onToggle: () => _toggle(item.id),
                    );
                  },
                ),
        );
      },
    );
  }

  PreferredSizeWidget _defaultAppBar(DownloadQueueManager queue) {
    final running = queue.activeCount;
    final hasPaused =
        queue.items.any((i) => i.status == DownloadStatus.paused);

    return AppBar(
      title: const Text('التحميلات'),
      actions: [
        if (running > 0)
          IconButton(
            icon: const Icon(Icons.pause_rounded),
            tooltip: 'إيقاف الكل',
            onPressed: queue.pauseAll,
          )
        else if (hasPaused)
          IconButton(
            icon: const Icon(Icons.play_arrow_rounded),
            tooltip: 'استئناف الكل',
            onPressed: queue.resumeAll,
          ),
        PopupMenuButton<String>(
          icon: const Icon(Icons.more_vert_rounded),
          onSelected: (value) async {
            switch (value) {
              case 'select':
                setState(() => _selectionMode = true);
              case 'clear_completed':
                await queue.removeCompleted();
              case 'clear_queue':
                final ok = await confirmDialog(
                  context,
                  title: 'إفراغ القائمة',
                  message: 'سيتم إلغاء كل التحميلات غير المكتملة. '
                      'الملفات المكتملة تبقى على الجهاز.',
                );
                if (ok) await queue.clearQueue();
            }
          },
          itemBuilder: (context) => const [
            PopupMenuItem(value: 'select', child: Text('تحديد')),
            PopupMenuItem(
                value: 'clear_completed',
                child: Text('حذف المكتملة من القائمة')),
            PopupMenuItem(value: 'clear_queue', child: Text('إفراغ القائمة')),
          ],
        ),
        const SizedBox(width: 4),
      ],
    );
  }

  PreferredSizeWidget _selectionAppBar(
      DownloadQueueManager queue, List<DownloadItem> items) {
    final allSelected =
        items.isNotEmpty && _selected.length == items.length;

    return AppBar(
      leading: IconButton(
        icon: const Icon(Icons.close_rounded),
        onPressed: _exitSelection,
      ),
      title: Text('${_selected.length} محدد'),
      actions: [
        IconButton(
          icon: Icon(allSelected
              ? Icons.deselect_rounded
              : Icons.select_all_rounded),
          tooltip: allSelected ? 'إلغاء التحديد' : 'تحديد الكل',
          onPressed: () => setState(() {
            if (allSelected) {
              _selected.clear();
            } else {
              _selected
                ..clear()
                ..addAll(items.map((i) => i.id));
            }
          }),
        ),
        IconButton(
          icon: const Icon(Icons.delete_outline_rounded),
          tooltip: 'حذف المحدد',
          onPressed: _selected.isEmpty
              ? null
              : () async {
                  final ok = await confirmDialog(
                    context,
                    title: 'حذف المحدد',
                    message:
                        'سيتم حذف ${_selected.length} ملفاً من الجهاز.',
                  );
                  if (!ok) return;
                  await queue.removeMany(_selected.toList());
                  _exitSelection();
                },
        ),
        const SizedBox(width: 4),
      ],
    );
  }
}

class _DownloadRow extends ConsumerWidget {
  const _DownloadRow({
    required this.item,
    required this.queue,
    required this.selected,
    required this.selectionMode,
    required this.onToggle,
  });

  final DownloadItem item;
  final DownloadQueueManager queue;
  final bool selected;
  final bool selectionMode;
  final VoidCallback onToggle;

  /// "الحلقة 03 - العنوان" for an episode, plain title for a film. There is no
  /// folder to give an episode its context any more, so the row carries it.
  String get _label {
    if (!item.isEpisode) return item.displayName;
    final number = item.episodeNumber;
    if (number == null || number == 0) return item.displayName;
    return 'الحلقة ${number.toString().padLeft(2, '0')} - ${item.displayName}';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final done = item.status == DownloadStatus.completed;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: selectionMode ? onToggle : null,
        onLongPress: onToggle,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  if (selectionMode)
                    Padding(
                      padding: const EdgeInsets.only(left: 4),
                      child: Checkbox(
                          value: selected, onChanged: (_) => onToggle()),
                    )
                  else if (done)
                    Padding(
                      padding: const EdgeInsets.only(left: 6),
                      child: Icon(Icons.check_circle_rounded,
                          size: 18, color: AppColors.success),
                    ),
                  Expanded(
                    child: Text(
                      _label,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          height: 1.4),
                    ),
                  ),
                ],
              ),
              if (item.seriesTitle != null)
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text(
                    item.seriesTitle!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontSize: 11, color: AppColors.textTertiary),
                  ),
                ),
              const SizedBox(height: 8),
              DownloadProgressBlock(item: item),
              DownloadActions(
                item: item,
                onPlay: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => PlayerPage(
                      title: item.displayName,
                      source: ref
                          .read(storagePathsProvider)
                          .absolute(item.relativePath),
                      resumeId: item.id,
                    ),
                  ),
                ),
                onSaveToGallery: () => _saveToGallery(context, ref),
                onPause: () => queue.pause(item.id),
                onResume: () => queue.resume(item.id),
                onCancel: () => queue.cancel(item.id),
                onDelete: () async {
                  final ok = await confirmDialog(
                    context,
                    title: 'حذف الملف',
                    message: 'سيتم حذف "${item.displayName}" من الجهاز.',
                  );
                  if (ok) await queue.remove(item.id);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _saveToGallery(BuildContext context, WidgetRef ref) async {
    final messenger = ScaffoldMessenger.of(context);
    final path = ref.read(storagePathsProvider).absolute(item.relativePath);
    try {
      if (!await Gal.hasAccess(toAlbum: true)) {
        await Gal.requestAccess(toAlbum: true);
      }
      await Gal.putVideo(path, album: AppConstants.appName);
      messenger.showSnackBar(
        const SnackBar(content: Text('حُفظ في معرض الجهاز')),
      );
    } on GalException catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text(switch (e.type) {
          GalExceptionType.accessDenied => 'الصلاحية مرفوضة. فعّلها من الإعدادات.',
          GalExceptionType.notEnoughSpace => 'لا توجد مساحة كافية.',
          GalExceptionType.notSupportedFormat =>
            'المعرض لا يدعم صيغة هذا الملف.',
          _ => 'تعذّر الحفظ في المعرض.',
        })),
      );
    }
  }
}
