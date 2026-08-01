import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/formatters.dart';
import '../../domain/entities/download_task.dart';

Color statusColorOf(DownloadStatus status) => switch (status) {
      DownloadStatus.completed => AppColors.success,
      DownloadStatus.failed => AppColors.danger,
      DownloadStatus.paused => AppColors.warning,
      DownloadStatus.running => AppColors.accent,
      _ => AppColors.textTertiary,
    };

/// Progress bar plus the status / size / speed / ETA line.
/// Extracted so the flat list, the film rows and the episode rows all render
/// progress identically.
class DownloadProgressBlock extends StatelessWidget {
  const DownloadProgressBlock({super.key, required this.item});

  final DownloadItem item;

  @override
  Widget build(BuildContext context) {
    final color = statusColorOf(item.status);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(3),
          child: LinearProgressIndicator(
            value: item.status == DownloadStatus.completed
                ? 1
                : (item.progress > 0 ? item.progress : null),
            minHeight: 4,
            color: color,
          ),
        ),
        const SizedBox(height: 6),
        DefaultTextStyle(
          style: TextStyle(fontSize: 11, color: AppColors.textTertiary),
          child: Row(
            children: [
              Text(item.status.label,
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: color)),
              const SizedBox(width: 8),
              if (item.status != DownloadStatus.completed &&
                  item.progress > 0) ...[
                Text(Formatters.percent(item.progress),
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: color)),
                const SizedBox(width: 8),
              ],
              if (item.totalBytes > 0)
                Text('${Formatters.bytes(item.receivedBytes)} / '
                    '${Formatters.bytes(item.totalBytes)}'),
              const Spacer(),
              if (item.status == DownloadStatus.running) ...[
                Text(Formatters.speed(item.speedBytesPerSecond)),
                if (item.etaSeconds > 0) ...[
                  const Text(' · '),
                  Text(Formatters.duration(item.etaSeconds)),
                ],
              ] else if (item.status == DownloadStatus.completed)
                Text(Formatters.bytes(item.totalBytes)),
            ],
          ),
        ),
        if (item.errorMessage != null)
          Padding(
            padding: const EdgeInsets.only(top: 5),
            child: Text(
              item.errorMessage!,
              style: TextStyle(fontSize: 11, color: AppColors.danger),
            ),
          ),
      ],
    );
  }
}

/// Pause / resume / retry / cancel / delete row.
class DownloadActions extends StatelessWidget {
  const DownloadActions({
    super.key,
    required this.item,
    required this.onPause,
    required this.onResume,
    required this.onCancel,
    required this.onDelete,
    this.onPlay,
    this.onSaveToGallery,
  });

  final DownloadItem item;
  final VoidCallback onPause;
  final VoidCallback onResume;
  final VoidCallback onCancel;
  final VoidCallback onDelete;

  /// Both only supplied once the file is fully downloaded.
  final VoidCallback? onPlay;
  final VoidCallback? onSaveToGallery;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        if (item.status == DownloadStatus.completed && onPlay != null)
          _Action(
              icon: Icons.play_circle_fill_rounded,
              label: 'تشغيل',
              onTap: onPlay!),
        if (item.status == DownloadStatus.completed &&
            onSaveToGallery != null)
          _Action(
              icon: Icons.save_alt_rounded,
              label: 'حفظ في المعرض',
              onTap: onSaveToGallery!),
        if (item.status == DownloadStatus.running)
          _Action(icon: Icons.pause_rounded, label: 'إيقاف', onTap: onPause),
        if (item.status == DownloadStatus.paused)
          _Action(
              icon: Icons.play_arrow_rounded,
              label: 'استئناف',
              onTap: onResume),
        if (item.status == DownloadStatus.failed ||
            item.status == DownloadStatus.canceled)
          _Action(
              icon: Icons.refresh_rounded, label: 'إعادة', onTap: onResume),
        if (!item.status.isTerminal)
          _Action(icon: Icons.close_rounded, label: 'إلغاء', onTap: onCancel),
        const Spacer(),
        _Action(
          icon: Icons.delete_outline_rounded,
          label: 'حذف',
          danger: true,
          onTap: onDelete,
        ),
      ],
    );
  }
}

class _Action extends StatelessWidget {
  const _Action({
    required this.icon,
    required this.label,
    required this.onTap,
    this.danger = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final color = danger ? AppColors.danger : AppColors.textSecondary;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 15, color: color),
            const SizedBox(width: 3),
            Text(label,
                style: TextStyle(
                    fontSize: 11, fontWeight: FontWeight.w600, color: color)),
          ],
        ),
      ),
    );
  }
}

/// Confirmation dialog shared by every destructive action in the library.
Future<bool> confirmDialog(
  BuildContext context, {
  required String title,
  required String message,
}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      backgroundColor: AppColors.surface,
      title: Text(title),
      content: Text(message, style: const TextStyle(height: 1.7)),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('إلغاء'),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: Text('تأكيد',
              style: TextStyle(color: AppColors.danger)),
        ),
      ],
    ),
  );
  return result ?? false;
}
