import 'package:dio/dio.dart';
import 'package:flutter/material.dart' show ThemeMode;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/datasources/local_store.dart';
import '../../data/datasources/secure_credentials_store.dart';
import '../../data/datasources/xtream_api.dart';
import '../../data/repositories/auth_repository_impl.dart';
import '../../data/repositories/catalog_repository_impl.dart';
import '../../data/repositories/download_repository_impl.dart';
import '../../data/repositories/favorites_repository_impl.dart';
import '../../domain/entities/credentials.dart';
import '../../domain/entities/download_settings.dart';
import '../../domain/repositories/auth_repository.dart';
import '../../domain/repositories/catalog_repository.dart';
import '../../domain/repositories/download_repository.dart';
import '../../domain/repositories/favorites_repository.dart';
import '../../domain/usecases/build_download_items.dart';
import '../../domain/usecases/filter_catalog.dart';
import '../../downloader/background_engine.dart';
import '../../downloader/download_engine.dart';
import '../../downloader/download_queue_manager.dart';
import '../../downloader/segmented_engine.dart';
import '../../downloader/storage_paths.dart';
import '../network/dio_client.dart';

/// Overridden in main() once the async bootstrap has completed.
final localStoreProvider = Provider<LocalStore>(
  (ref) => throw UnimplementedError('localStoreProvider must be overridden'),
);

final storagePathsProvider = Provider<StoragePaths>(
  (ref) => throw UnimplementedError('storagePathsProvider must be overridden'),
);

final dioProvider = Provider<Dio>((ref) {
  final dio = DioClient.create();
  ref.onDispose(dio.close);
  return dio;
});

final xtreamApiProvider =
    Provider<XtreamApi>((ref) => XtreamApi(ref.watch(dioProvider)));

final secureStoreProvider =
    Provider<SecureCredentialsStore>((ref) => SecureCredentialsStore());

final authRepositoryProvider = Provider<AuthRepository>(
  (ref) => AuthRepositoryImpl(
    ref.watch(xtreamApiProvider),
    ref.watch(secureStoreProvider),
    ref.watch(localStoreProvider),
  ),
);

/// The signed-in session. Null means "show the login screen".
class SessionNotifier extends Notifier<Credentials?> {
  @override
  Credentials? build() => null;

  void set(Credentials? value) => state = value;
}

final sessionProvider =
    NotifierProvider<SessionNotifier, Credentials?>(SessionNotifier.new);

final catalogRepositoryProvider = Provider<CatalogRepository>(
  (ref) => CatalogRepositoryImpl(
    ref.watch(xtreamApiProvider),
    ref.watch(localStoreProvider),
    () {
      final session = ref.read(sessionProvider);
      if (session == null) {
        throw StateError('No active session');
      }
      return session;
    },
  ),
);

final downloadRepositoryProvider = Provider<DownloadRepository>(
  (ref) => DownloadRepositoryImpl(ref.watch(localStoreProvider)),
);

final favoritesRepositoryProvider = Provider<FavoritesRepository>(
  (ref) => FavoritesRepositoryImpl(ref.watch(localStoreProvider)),
);

// ----------------------------------------------------------------- settings

class SettingsNotifier extends Notifier<DownloadSettings> {
  @override
  DownloadSettings build() => ref.watch(localStoreProvider).readSettings();

  Future<void> update(DownloadSettings value) async {
    final previousEngine = state.engineMode;
    state = value;
    await ref.read(localStoreProvider).writeSettings(value);

    final queue = ref.read(downloadQueueProvider);
    if (previousEngine != value.engineMode) {
      await queue.swapEngine(_buildEngine(ref, value.engineMode));
    }
    await queue.updateSettings(value);
  }
}

final settingsProvider =
    NotifierProvider<SettingsNotifier, DownloadSettings>(SettingsNotifier.new);

DownloadEngine _buildEngine(Ref ref, EngineMode mode) {
  final paths = ref.read(storagePathsProvider);
  return switch (mode) {
    EngineMode.background => BackgroundDownloadEngine(paths),
    EngineMode.turbo => SegmentedDownloadEngine(
        ref.read(dioProvider),
        ref.read(xtreamApiProvider),
        paths,
      ),
  };
}

// --------------------------------------------------------------- appearance

/// Light / dark / follow-the-system, persisted between launches.
class ThemeModeNotifier extends Notifier<ThemeMode> {
  @override
  ThemeMode build() {
    final stored = ref.watch(localStoreProvider).readThemeMode();
    return switch (stored) {
      'light' => ThemeMode.light,
      'dark' => ThemeMode.dark,
      _ => ThemeMode.system,
    };
  }

  Future<void> set(ThemeMode mode) async {
    state = mode;
    await ref.read(localStoreProvider).writeThemeMode(switch (mode) {
      ThemeMode.light => 'light',
      ThemeMode.dark => 'dark',
      ThemeMode.system => 'system',
    });
  }
}

final themeModeProvider =
    NotifierProvider<ThemeModeNotifier, ThemeMode>(ThemeModeNotifier.new);

// -------------------------------------------------------------------- queue

/// Long-lived scheduler. Created once and kept alive for the app's lifetime.
final downloadQueueProvider = Provider<DownloadQueueManager>((ref) {
  final settings = ref.read(localStoreProvider).readSettings();
  final manager = DownloadQueueManager(
    repository: ref.watch(downloadRepositoryProvider),
    paths: ref.watch(storagePathsProvider),
    engine: _buildEngine(ref, settings.engineMode),
    settings: settings,
  );
  ref.onDispose(manager.dispose);
  return manager;
});

// ----------------------------------------------------------------- usecases

final buildDownloadItemsProvider =
    Provider<BuildDownloadItems>((ref) => const BuildDownloadItems());

final filterCatalogProvider =
    Provider<FilterCatalog>((ref) => const FilterCatalog());
