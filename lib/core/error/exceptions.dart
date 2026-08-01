/// Thrown when the Xtream server responds but rejects the credentials.
class AuthException implements Exception {
  const AuthException(this.message);
  final String message;
  @override
  String toString() => 'AuthException: $message';
}

/// Thrown for transport-level problems (timeout, DNS, socket, TLS).
class NetworkException implements Exception {
  const NetworkException(this.message);
  final String message;
  @override
  String toString() => 'NetworkException: $message';
}

/// Thrown when the server returns a payload that cannot be parsed.
class ServerException implements Exception {
  const ServerException(this.message, {this.statusCode});
  final String message;
  final int? statusCode;
  @override
  String toString() => 'ServerException($statusCode): $message';
}

/// Thrown for local persistence failures.
class CacheException implements Exception {
  const CacheException(this.message);
  final String message;
  @override
  String toString() => 'CacheException: $message';
}

/// Thrown when a download cannot be written to disk.
class StorageException implements Exception {
  const StorageException(this.message);
  final String message;
  @override
  String toString() => 'StorageException: $message';
}
