import '../entities/credentials.dart';
import '../../core/utils/result.dart';

abstract interface class AuthRepository {
  /// Validates against the server and, on success, persists to the keychain.
  Future<Result<Credentials>> login(Credentials credentials);

  /// Returns stored credentials, or null when the user has never logged in.
  Future<Credentials?> readStored();

  /// Clears the keychain entry and any cached catalog data.
  Future<void> logout();
}
