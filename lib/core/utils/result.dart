import '../error/failures.dart';

/// Lightweight Either-style result used across repository boundaries.
sealed class Result<T> {
  const Result();

  bool get isSuccess => this is Success<T>;

  T? get valueOrNull => this is Success<T> ? (this as Success<T>).value : null;

  Failure? get failureOrNull =>
      this is Err<T> ? (this as Err<T>).failure : null;

  R fold<R>({
    required R Function(T value) onSuccess,
    required R Function(Failure failure) onFailure,
  }) {
    final self = this;
    if (self is Success<T>) return onSuccess(self.value);
    return onFailure((self as Err<T>).failure);
  }
}

class Success<T> extends Result<T> {
  const Success(this.value);
  final T value;
}

class Err<T> extends Result<T> {
  const Err(this.failure);
  final Failure failure;
}

/// Runs [body] and converts any thrown object into an [Err].
Future<Result<T>> guard<T>(Future<T> Function() body) async {
  try {
    return Success(await body());
  } catch (e) {
    return Err(mapErrorToFailure(e));
  }
}
