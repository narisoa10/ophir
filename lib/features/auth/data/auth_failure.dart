sealed class AuthFailure implements Exception {
  const AuthFailure();
}

final class UserNotFoundAuthFailure extends AuthFailure {
  const UserNotFoundAuthFailure();
}

final class PasswordRequiredAuthFailure extends AuthFailure {
  const PasswordRequiredAuthFailure();
}

final class GoogleAuthFailure extends AuthFailure {
  const GoogleAuthFailure();
}

final class RateLimitedAuthFailure extends AuthFailure {
  const RateLimitedAuthFailure();
}

final class ServerAuthFailure extends AuthFailure {
  const ServerAuthFailure();
}

final class UnknownAuthFailure extends AuthFailure {
  const UnknownAuthFailure();
}