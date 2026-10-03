import 'package:flutter_test/flutter_test.dart';
import 'package:ophir/core/errors/app_failure.dart';
import 'package:ophir/features/accounts/data/plaid/plaid_edge_failure.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

FunctionException _exception(int status, Object? details) {
  return FunctionException(status: status, details: details);
}

Map<String, dynamic> _error(String code) => {
  'error': {'code': code},
};

void main() {
  group('plaidFailureFromFunctionException', () {
    test('item_login_required is a typed failure, not Unknown', () {
      final failure = plaidFailureFromFunctionException(
        _exception(409, _error('item_login_required')),
      );

      expect(failure, isA<PlaidItemLoginRequiredFailure>());
    });

    test('reconnect_unavailable is a typed failure', () {
      final failure = plaidFailureFromFunctionException(
        _exception(409, _error('reconnect_unavailable')),
      );

      expect(failure, isA<PlaidReconnectUnavailableFailure>());
    });

    test('connection_disconnected is a typed failure', () {
      final failure = plaidFailureFromFunctionException(
        _exception(409, _error('connection_disconnected')),
      );

      expect(failure, isA<PlaidConnectionDisconnectedFailure>());
    });

    test('lifecycle backend errors stay Unknown', () {
      for (final entry in const {
        'plaid_outcome_unknown': 502,
        'local_lifecycle_failed': 500,
        'supabase_config_missing': 500,
      }.entries) {
        expect(
          plaidFailureFromFunctionException(
            _exception(entry.value, _error(entry.key)),
          ),
          isA<UnknownFailure>(),
        );
      }
    });

    test('connection_not_found maps to NotFoundFailure', () {
      final failure = plaidFailureFromFunctionException(
        _exception(404, _error('connection_not_found')),
      );

      expect(failure, isA<NotFoundFailure>());
    });

    test('unauthorized and validation keep status mapping', () {
      expect(
        plaidFailureFromFunctionException(
          _exception(401, _error('unauthorized')),
        ),
        isA<UnauthorizedFailure>(),
      );
      expect(
        plaidFailureFromFunctionException(
          _exception(400, _error('invalid_request')),
        ),
        isA<ValidationFailure>(),
      );
    });

    test('generic backend errors stay Unknown', () {
      expect(
        plaidFailureFromFunctionException(
          _exception(502, _error('plaid_request_failed')),
        ),
        isA<UnknownFailure>(),
      );
      expect(
        plaidFailureFromFunctionException(_exception(500, null)),
        isA<UnknownFailure>(),
      );
      expect(
        plaidFailureFromFunctionException(_exception(409, 'plain text')),
        isA<UnknownFailure>(),
      );
      expect(
        plaidFailureFromFunctionException(
          _exception(409, {'error': 'item_login_required'}),
        ),
        isA<UnknownFailure>(),
      );
    });
  });
}
