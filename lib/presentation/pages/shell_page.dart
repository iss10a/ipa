import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/di/providers.dart';
import '../../domain/entities/download_task.dart';
import 'downloads_page.dart';
import 'home_page.dart';
import 'movies_page.dart';
import 'series_page.dart';
import 'settings_page.dart';

class ShellPage extends ConsumerStatefulWidget {
  const ShellPage({super.key});

  @override
  ConsumerState<ShellPage> createState() => _ShellPageState();
}

class _ShellPageState extends ConsumerState<ShellPage> {
  int _index = 0;

  static const _pages = [
    HomePage(),
    MoviesPage(),
    SeriesPage(),
    DownloadsPage(),
    SettingsPage(),
  ];

  @override
  Widget build(BuildContext context) {
    final queue = ref.watch(downloadQueueProvider);

    return Scaffold(
      body: IndexedStack(index: _index, children: _pages),
      bottomNavigationBar: AnimatedBuilder(
        animation: queue,
        builder: (context, _) {
          final pending = queue.items
              .where((i) =>
                  i.status == DownloadStatus.running ||
                  i.status == DownloadStatus.queued)
              .length;

          return BottomNavigationBar(
            currentIndex: _index,
            onTap: (value) => setState(() => _index = value),
            items: [
              const BottomNavigationBarItem(
                icon: Icon(Icons.home_outlined),
                activeIcon: Icon(Icons.home_rounded),
                label: 'الرئيسية',
              ),
              const BottomNavigationBarItem(
                icon: Icon(Icons.movie_outlined),
                activeIcon: Icon(Icons.movie_rounded),
                label: 'أفلام',
              ),
              const BottomNavigationBarItem(
                icon: Icon(Icons.tv_outlined),
                activeIcon: Icon(Icons.tv_rounded),
                label: 'مسلسلات',
              ),
              BottomNavigationBarItem(
                icon: _BadgedIcon(
                  icon: Icons.download_outlined,
                  count: pending,
                ),
                activeIcon: _BadgedIcon(
                  icon: Icons.download_rounded,
                  count: pending,
                ),
                label: 'التحميلات',
              ),
              const BottomNavigationBarItem(
                icon: Icon(Icons.settings_outlined),
                activeIcon: Icon(Icons.settings_rounded),
                label: 'الإعدادات',
              ),
            ],
          );
        },
      ),
    );
  }
}

class _BadgedIcon extends StatelessWidget {
  const _BadgedIcon({required this.icon, required this.count});

  final IconData icon;
  final int count;

  @override
  Widget build(BuildContext context) {
    if (count == 0) return Icon(icon);
    return Badge(
      label: Text('$count'),
      offset: const Offset(-8, -4),
      child: Icon(icon),
    );
  }
}
