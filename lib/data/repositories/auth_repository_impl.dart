import '../../core/utils/result.dart';
import '../../domain/entities/credentials.dart';
import '../../domain/repositories/auth_repository.dart';
import '../datasources/local_store.dart';
import '../datasources/secure_credentials_store.dart';
import '../datasources/xtream_api.dart';

class AuthRepositoryImpl implements AuthRepository {
  AuthRepositoryImpl(this._api, this._store, this._local);

  final XtreamApi _api;
  final SecureCredentialsStore _store;
  final LocalStore _local;

  @override
  Future<Result<Credentials>> login(Credentials credentials) =>
      guard(() async {
        await _api.authenticate(credentials);
        await _store.save(credentials);
        return credentials;
      });

  @override
  Future<Credentials?> readStored() => _store.read();

  @override
  Future<void> logout() async {
    await _store.clear();
    await _local.clearCatalog();
  }
}
