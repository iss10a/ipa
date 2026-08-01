/// Global, compile-time application constants.
class AppConstants {
  AppConstants._();

  static const String appName = 'P V O';

  /// Direct support conversation, opened before or after login.
  static const String supportWhatsAppUrl = 'https://wa.me/96896696889';

  /// Hive box names.
  static const String boxDownloads = 'downloads_box';
  static const String boxCatalogCache = 'catalog_cache_box';
  static const String boxSettings = 'settings_box';
  static const String boxFavorites = 'favorites_box';
  static const String boxPlayback = 'playback_box';

  /// Key inside the settings box holding the chosen theme mode.
  static const String keyThemeMode = 'theme_mode';

  /// Secure storage keys.
  static const String keyServerUrl = 'xt_server_url';
  static const String keyUsername = 'xt_username';
  static const String keyPassword = 'xt_password';

  /// Root folder created inside the app's private Application Support
  /// directory. Nothing here is visible in the Files app.
  static const String downloadsRoot = 'Media';
  static const String moviesFolder = 'Movies';
  static const String seriesFolder = 'Series';

  /// Networking.
  static const Duration connectTimeout = Duration(seconds: 20);
  static const Duration receiveTimeout = Duration(seconds: 40);

  /// Catalog cache lifetime before a background refresh is triggered.
  static const Duration catalogCacheTtl = Duration(hours: 6);

  /// Page size used by the lazy-loading grids.
  static const int pageSize = 30;
}
