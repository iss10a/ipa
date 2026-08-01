import 'dart:convert';

import 'package:hive_flutter/hive_flutter.dart';

import '../../core/constants/app_constants.dart';
import '../../domain/entities/download_settings.dart';

/// Hive-backed persistence. Values are stored as JSON strings rather than typed
/// adapters, which keeps the project free of generated code and makes schema
/// changes forward-compatible.
class LocalStore {
  LocalStore(this._downloads, this._catalog, this._settings, this._favorites,
      this._playback);

  final Box<String> _downloads;
  final Box<String> _catalog;
  final Box<String> _settings;
  final Box<String> _favorites;
  final Box<String> _playback;

  static Future<LocalStore> open() async {
    await Hive.initFlutter();
    final downloads = await Hive.openBox<String>(AppConstants.boxDownloads);
    final catalog = await Hive.openBox<String>(AppConstants.boxCatalogCache);
    final settings = await Hive.openBox<String>(AppConstants.boxSettings);
    final favorites = await Hive.openBox<String>(AppConstants.boxFavorites);
    final playback = await Hive.openBox<String>(AppConstants.boxPlayback);
    return LocalStore(downloads, catalog, settings, favorites, playback);
  }

  // --------------------------------------------------------------- downloads

  List<Map<String, dynamic>> readDownloads() {
    final out = <Map<String, dynamic>>[];
    for (final raw in _downloads.values) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is Map) out.add(Map<String, dynamic>.from(decoded));
      } catch (_) {
        // Skip corrupt rows instead of failing the whole load.
      }
    }
    return out;
  }

  Future<void> writeDownload(String id, Map<String, dynamic> json) =>
      _downloads.put(id, jsonEncode(json));

  Future<void> writeDownloads(Map<String, Map<String, dynamic>> entries) =>
      _downloads.putAll(
        entries.map((key, value) => MapEntry(key, jsonEncode(value))),
      );

  Future<void> deleteDownload(String id) => _downloads.delete(id);

  Future<void> deleteDownloads(Iterable<String> ids) =>
      _downloads.deleteAll(ids);

  Future<void> clearDownloads() => _downloads.clear();

  // ----------------------------------------------------------------- catalog

  /// Returns cached JSON for [key] when it is still within the TTL.
  dynamic readCatalog(String key) {
    final raw = _catalog.get(key);
    if (raw == null) return null;
    try {
      final envelope = jsonDecode(raw) as Map<String, dynamic>;
      final savedAt =
          DateTime.fromMillisecondsSinceEpoch(envelope['at'] as int? ?? 0);
      if (DateTime.now().difference(savedAt) > AppConstants.catalogCacheTtl) {
        return null;
      }
      return envelope['data'];
    } catch (_) {
      return null;
    }
  }

  Future<void> writeCatalog(String key, dynamic data) => _catalog.put(
        key,
        jsonEncode({'at': DateTime.now().millisecondsSinceEpoch, 'data': data}),
      );

  Future<void> clearCatalog() => _catalog.clear();

  // ---------------------------------------------------------------- settings

  DownloadSettings readSettings() {
    final raw = _settings.get('download_settings');
    if (raw == null) return const DownloadSettings();
    try {
      return DownloadSettings.fromJson(
          jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return const DownloadSettings();
    }
  }

  Future<void> writeSettings(DownloadSettings settings) =>
      _settings.put('download_settings', jsonEncode(settings.toJson()));

  // --------------------------------------------------------------- favorites

  List<Map<String, dynamic>> readFavorites() {
    final out = <Map<String, dynamic>>[];
    for (final raw in _favorites.values) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is Map) out.add(Map<String, dynamic>.from(decoded));
      } catch (_) {
        // Skip a corrupt row rather than losing the whole list.
      }
    }
    return out;
  }

  Future<void> writeFavorite(String id, Map<String, dynamic> json) =>
      _favorites.put(id, jsonEncode(json));

  Future<void> deleteFavorite(String id) => _favorites.delete(id);

  bool hasFavorite(String id) => _favorites.containsKey(id);

  // ---------------------------------------------------------------- playback

  /// Seconds already watched for a downloaded item, so playback resumes where
  /// the viewer stopped rather than restarting the file.
  int readPosition(String id) {
    final raw = _playback.get(id);
    return raw == null ? 0 : (int.tryParse(raw) ?? 0);
  }

  Future<void> writePosition(String id, int seconds) =>
      _playback.put(id, '$seconds');

  Future<void> clearPosition(String id) => _playback.delete(id);

  // ------------------------------------------------------------- appearance

  /// 'light' | 'dark' | 'system'. Survives restarts.
  String readThemeMode() =>
      _settings.get(AppConstants.keyThemeMode) ?? 'system';

  Future<void> writeThemeMode(String value) =>
      _settings.put(AppConstants.keyThemeMode, value);
}
