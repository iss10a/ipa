import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/constants/app_constants.dart';
import 'core/di/providers.dart';
import 'core/theme/app_colors.dart';
import 'core/theme/app_theme.dart';
import 'presentation/pages/login_page.dart';
import 'presentation/pages/shell_page.dart';

class XtreamDownloaderApp extends ConsumerWidget {
  const XtreamDownloaderApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp(
      title: AppConstants.appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: ref.watch(themeModeProvider),

      // The entire app is Arabic and right-to-left.
      locale: const Locale('ar'),
      supportedLocales: const [Locale('ar'), Locale('en')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      builder: (context, child) {
        // Point the palette at whichever brightness actually won, so widgets
        // reading AppColors directly stay in step with the ThemeData.
        AppColors.apply(Theme.of(context).brightness);
        return Directionality(
          textDirection: TextDirection.rtl,
          child: MediaQuery.withNoTextScaling(child: child ?? const SizedBox()),
        );
      },

      home: const _Bootstrap(),
    );
  }
}

/// Decides between the login screen and the main shell, and restores any
/// downloads that were in progress when the app was last closed.
class _Bootstrap extends ConsumerStatefulWidget {
  const _Bootstrap();

  @override
  ConsumerState<_Bootstrap> createState() => _BootstrapState();
}

class _BootstrapState extends ConsumerState<_Bootstrap> {
  late final Future<bool> _startup;

  @override
  void initState() {
    super.initState();
    _startup = _restore();
  }

  Future<bool> _restore() async {
    // The queue must come up regardless of session state so background
    // transfers that finished while the app was closed are reconciled.
    await ref.read(downloadQueueProvider).initialize();

    final stored = await ref.read(authRepositoryProvider).readStored();
    if (stored == null || !stored.isValid) return false;
    ref.read(sessionProvider.notifier).set(stored);
    return true;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: _startup,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const _SplashScreen();
        }
        final session = ref.watch(sessionProvider);
        if (session == null) return const LoginPage();
        return const ShellPage();
      },
    );
  }
}

class _SplashScreen extends StatelessWidget {
  const _SplashScreen();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.download_for_offline_outlined, size: 64),
            SizedBox(height: 20),
            SizedBox(
              width: 28,
              height: 28,
              child: CircularProgressIndicator(strokeWidth: 2.5),
            ),
          ],
        ),
      ),
    );
  }
}
