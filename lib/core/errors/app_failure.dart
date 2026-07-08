sealed class AppFailure implements Exception {
  const AppFailure();
}

final class UnauthorizedFailure extends AppFailure {
  const UnauthorizedFailure();
}

final class NotFoundFailure extends AppFailure {
  const NotFoundFailure();
}

final class ValidationFailure extends AppFailure {
  const ValidationFailure();
}

final class DatabaseFailure extends AppFailure {
  const DatabaseFailure();
}

final class NetworkFailure extends AppFailure {
  const NetworkFailure();
}

final class UnknownFailure extends AppFailure {
  const UnknownFailure();
}