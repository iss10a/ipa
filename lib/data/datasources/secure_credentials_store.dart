import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../core/constants/app_constants.dart';
import '../../domain/entities/credentials.dart';

/// Persists the Xtream login in the iOS keychain, so it survives reinstalls of
/// the app data directory and is never written to plain preferences.
class SecureCredentialsStore {
  SecureCredentialsStore([FlutterSecureStorage? storage])
      : _storage = storage ??
            const FlutterSecureStorage(
              iOptions: IOSOptions(
                accessibility: KeychainAccessibility.first_unlock,
              ),
            );

  final FlutterSecureStorage _storage;

  Future<void> save(Credentials creds) async {
    await Future.wait([
      _storage.write(key: AppConstants.keyServerUrl, value: creds.baseUrl),
      _storage.write(key: AppConstants.keyUsername, value: creds.username),
      _storage.write(key: AppConstants.keyPassword, value: creds.password),
    ]);
  }

  Future<Credentials?> read() async {
    final url = await _storage.read(key: AppConstants.keyServerUrl);
    final user = await _storage.read(key: AppConstants.keyUsername);
    final pass = await _storage.read(key: AppConstants.keyPassword);
    if (url == null || user == null || pass == null) return null;
    if (url.isEmpty || user.isEmpty) return null;
    return Credentials(serverUrl: url, username: user, password: pass);
  }

  Future<void> clear() async {
    await Future.wait([
      _storage.delete(key: AppConstants.keyServerUrl),
      _storage.delete(key: AppConstants.keyUsername),
      _storage.delete(key: AppConstants.keyPassword),
    ]);
  }
}
