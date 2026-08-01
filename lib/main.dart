import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_kit/media_kit.dart';

import 'app.dart';
import 'core/di/providers.dart';
import 'data/datasources/local_store.dart';
import 'downloader/storage_paths.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Must run before any Player is created.
  MediaKit.ensureInitialized();

  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // Async dependencies are resolved once here so no widget ever waits on IO.
  final localStore = await LocalStore.open();
  final storagePaths = await StoragePaths.instance();

  runApp(
    ProviderScope(
      overrides: [
        localStoreProvider.overrideWithValue(localStore),
        storagePathsProvider.overrideWithValue(storagePaths),
      ],
      child: const XtreamDownloaderApp(),
    ),
  );
}
