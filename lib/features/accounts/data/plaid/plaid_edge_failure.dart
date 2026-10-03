import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/errors/app_failure.dart';

/// Reads the `{ "error": { "code": ... } }` body returned by Ophir Plaid Edge
/// functions.
String? plaidEdgeErrorCode(Object? details) {
  if (details is! Map) {
    return null;
  }

  final error = details['error'];
  if (error is! Map) {
    return null;
  }

  final code = error['code'];
  return code is String && code.isNotEmpty ? code : null;
}

AppFailure plaidFailureFromFunctionException(FunctionException exception) {
  switch (plaidEdgeErrorCode(exception.details)) {
    case 'item_login_required':
      return const PlaidItemLoginRequiredFailure();
    case 'reconnect_unavailable':
      return const PlaidReconnectUnavailableFailure();
    case 'connection_disconnected':
      return const PlaidConnectionDisconnectedFailure();
    case 'connection_not_found':
      return const NotFoundFailure();
  }

  return switch (exception.status) {
    401 => const UnauthorizedFailure(),
    400 => const ValidationFailure(),
    404 => const NotFoundFailure(),
    _ => const UnknownFailure(),
  };
}
