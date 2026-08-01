import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/di/providers.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/formatters.dart';
import '../providers/catalog_providers.dart';

class SettingsPage extends ConsumerStatefulWidget {
  const SettingsPage({super.key});

  @override
  ConsumerState<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends ConsumerState<SettingsPage> {
  int? _usedBytes;

  @override
  void initState() {
    super.initState();
    _loadUsage();
  }

  Future<void> _loadUsage() async {
    final bytes = await ref.read(storagePathsProvider).usedBytes();
    if (mounted) setState(() => _usedBytes = bytes);
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(sessionProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('الإعدادات')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
        children: [
          const _SectionTitle('الحساب'),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _KeyValue(
                    label: 'الخادم',
                    value: session?.baseUrl ?? '—',
                  ),
                  const SizedBox(height: 10),
                  _KeyValue(
                    label: 'المستخدم',
                    value: session?.username ?? '—',
                  ),
                ],
              ),
            ),
          ),

          const _SectionTitle('التخزين'),
          Card(
            child: ListTile(
              leading: const Icon(Icons.sd_storage_outlined),
              title: const Text('المساحة المستخدمة',
                  style:
                      TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
              subtitle: Text(
                _usedBytes == null
                    ? 'جارٍ الحساب…'
                    : Formatters.bytes(_usedBytes!),
                style: TextStyle(
                    fontSize: 12, color: AppColors.textTertiary),
              ),
              trailing: IconButton(
                icon: const Icon(Icons.refresh_rounded, size: 20),
                onPressed: _loadUsage,
              ),
            ),
          ),
          Card(
            child: ListTile(
              leading: const Icon(Icons.cleaning_services_outlined),
              title: const Text('مسح ذاكرة المكتبة',
                  style:
                      TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
              subtitle: Text(
                'يعيد جلب الأفلام والمسلسلات من الخادم. لا يحذف الملفات.',
                style:
                    TextStyle(fontSize: 12, color: AppColors.textTertiary),
              ),
              onTap: () async {
                await ref.read(catalogRepositoryProvider).clearCache();
                ref
                  ..invalidate(moviesProvider)
                  ..invalidate(seriesProvider)
                  ..invalidate(movieCategoriesProvider)
                  ..invalidate(seriesCategoriesProvider);
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('تم مسح الذاكرة المؤقتة')),
                );
              },
            ),
          ),

          const SizedBox(height: 28),
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.danger,
              side: BorderSide(color: AppColors.danger.withValues(alpha: 0.4)),
            ),
            icon: const Icon(Icons.logout_rounded, size: 20),
            label: const Text('تسجيل الخروج'),
            onPressed: () => _logout(context),
          ),
          const SizedBox(height: 20),
          Center(
            child: Text(
              'الإصدار 1.0.0',
              style: TextStyle(fontSize: 11, color: AppColors.textTertiary),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _logout(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('تسجيل الخروج'),
        content: const Text(
          'سيتم حذف بيانات الدخول من الجهاز. الملفات المحمّلة تبقى كما هي.',
          style: TextStyle(height: 1.7),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('إلغاء'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text('خروج',
                style: TextStyle(color: AppColors.danger)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    await ref.read(downloadQueueProvider).pauseAll();
    await ref.read(authRepositoryProvider).logout();
    ref.read(sessionProvider.notifier).set(null);
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(4, 24, 4, 10),
        child: Text(
          text,
          style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: AppColors.textSecondary),
        ),
      );
}

class _KeyValue extends StatelessWidget {
  const _KeyValue({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 80,
          child: Text(label,
              style: TextStyle(
                  fontSize: 13, color: AppColors.textTertiary)),
        ),
        Expanded(
          child: Text(
            value,
            textDirection: TextDirection.ltr,
            textAlign: TextAlign.left,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
          ),
        ),
      ],
    );
  }
}
