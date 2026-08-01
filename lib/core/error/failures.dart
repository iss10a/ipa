import 'exceptions.dart';

/// Domain-level error type. Presentation layer only ever sees a [Failure],
/// never a raw exception, so error text can be localised in one place.
sealed class Failure {
  const Failure(this.message);
  final String message;
}

class AuthFailure extends Failure {
  const AuthFailure(super.message);
}

class NetworkFailure extends Failure {
  const NetworkFailure(super.message);
}

class ServerFailure extends Failure {
  const ServerFailure(super.message);
}

class CacheFailure extends Failure {
  const CacheFailure(super.message);
}

class StorageFailure extends Failure {
  const StorageFailure(super.message);
}

class UnknownFailure extends Failure {
  const UnknownFailure(super.message);
}

/// Maps a thrown object onto a [Failure] carrying an Arabic user-facing message.
Failure mapErrorToFailure(Object error) {
  return switch (error) {
    final AuthException e => AuthFailure(e.message),
    final NetworkException e => NetworkFailure(e.message),
    final ServerException e => ServerFailure(e.message),
    final CacheException e => CacheFailure(e.message),
    final StorageException e => StorageFailure(e.message),
    _ => const UnknownFailure('حدث خطأ غير متوقع. حاول مرة أخرى.'),
  };
}
