import 'package:flutter_test/flutter_test.dart';
import 'package:ophir/core/errors/app_failure.dart';
import 'package:ophir/features/accounts/data/plaid/plaid_connect_service.dart';
import 'package:ophir/features/accounts/domain/entities/plaid_connection_health.dart';

import '../../support/plaid_test_fakes.dart';

const _connectionId = '22222222-2222-4222-8222-222222222222';

FakePlaidFunctions _repairBackend({
  FakeFunctionHandler? createLinkToken,
  FakeFunctionHandler? refresh,
}) {
  return FakePlaidFunctions({
    'plaid-create-link-token':
        createLinkToken ??
        (_) => okResponse({
          'link_token': 'link-update-token',
          'expiration': '2026-10-03T14:00:00Z',
          'mode': 'update',
        }),
    'plaid-refresh-item-status':
        refresh ??
        (_) => okResponse({'status': 'active', 'status_reason': null}),
  });
}

void main() {
  group('reconnect (update mode)', () {
    test('requests update token for the connection and opens Link once', () async {
      final functions = _repairBackend();
      final link = FakePlaidLink();

      await fakeConnectService(
        functions,
        link,
      ).reconnect(connectionId: _connectionId, locale: 'fr-CA');

      final tokenCall = functions.calls.first;
      expect(tokenCall.functionName, 'plaid-create-link-token');
      expect(tokenCall.body['connection_id'], _connectionId);
      expect(tokenCall.body['locale'], 'fr-CA');
      expect(link.openedTokens, ['link-update-token']);
    });

    test('Link success refreshes health and never exchanges a public token', () async {
      final functions = _repairBackend();
      final link = FakePlaidLink();

      final outcome = await fakeConnectService(
        functions,
        link,
      ).reconnect(connectionId: _connectionId, locale: 'en-CA');

      expect(functions.functionNames, [
        'plaid-create-link-token',
        'plaid-refresh-item-status',
      ]);
      expect(functions.calls.last.body, {'connection_id': _connectionId});
      expect(functions.functionNames, isNot(contains('plaid-exchange-public-token')));
      expect(outcome, isA<PlaidReconnectConfirmed>());
      expect(
        (outcome as PlaidReconnectConfirmed).refresh.status,
        PlaidConnectionStatus.active,
      );
    });

    test('server still login_required is reported as such', () async {
      final functions = _repairBackend(
        refresh: (_) => okResponse({
          'status': 'login_required',
          'status_reason': 'consent_expired',
        }),
      );

      final outcome = await fakeConnectService(
        functions,
        FakePlaidLink(),
      ).reconnect(connectionId: _connectionId, locale: 'en-CA');

      final refresh = (outcome as PlaidReconnectConfirmed).refresh;
      expect(refresh.status, PlaidConnectionStatus.loginRequired);
      expect(refresh.statusReason, PlaidConnectionStatusReason.consentExpired);
    });

    test('refresh failure after Link success is not a successful repair', () async {
      final functions = _repairBackend(
        refresh: (_) => throw edgeError(502, 'plaid_request_failed'),
      );

      final outcome = await fakeConnectService(
        functions,
        FakePlaidLink(),
      ).reconnect(connectionId: _connectionId, locale: 'en-CA');

      expect(outcome, isA<PlaidReconnectFailed>());
      expect((outcome as PlaidReconnectFailed).failure, isA<UnknownFailure>());
    });

    test('unknown refresh status fails closed', () async {
      final functions = _repairBackend(
        refresh: (_) => okResponse({'status': 'future_status'}),
      );

      final outcome = await fakeConnectService(
        functions,
        FakePlaidLink(),
      ).reconnect(connectionId: _connectionId, locale: 'en-CA');

      expect(outcome, isA<PlaidReconnectFailed>());
    });

    test('cancel does not refresh or exchange', () async {
      final functions = _repairBackend();

      final outcome = await fakeConnectService(
        functions,
        FakePlaidLink(result: const PlaidLinkSessionExited()),
      ).reconnect(connectionId: _connectionId, locale: 'en-CA');

      expect(outcome, isA<PlaidReconnectCancelled>());
      expect(functions.functionNames, ['plaid-create-link-token']);
    });

    test('Link error is a failure without refresh', () async {
      final functions = _repairBackend();

      final outcome = await fakeConnectService(
        functions,
        FakePlaidLink(result: const PlaidLinkSessionFailed()),
      ).reconnect(connectionId: _connectionId, locale: 'en-CA');

      expect(outcome, isA<PlaidReconnectFailed>());
      expect(functions.functionNames, ['plaid-create-link-token']);
    });

    test('reconnect_unavailable stops before Link', () async {
      final functions = _repairBackend(
        createLinkToken: (_) => throw edgeError(409, 'reconnect_unavailable'),
      );
      final link = FakePlaidLink();

      final outcome = await fakeConnectService(
        functions,
        link,
      ).reconnect(connectionId: _connectionId, locale: 'en-CA');

      expect(
        (outcome as PlaidReconnectFailed).failure,
        isA<PlaidReconnectUnavailableFailure>(),
      );
      expect(link.openedTokens, isEmpty);
      expect(functions.calls, hasLength(1));
    });

    test('connection_not_found stops before Link', () async {
      final functions = _repairBackend(
        createLinkToken: (_) => throw edgeError(404, 'connection_not_found'),
      );
      final link = FakePlaidLink();

      final outcome = await fakeConnectService(
        functions,
        link,
      ).reconnect(connectionId: _connectionId, locale: 'en-CA');

      expect((outcome as PlaidReconnectFailed).failure, isA<NotFoundFailure>());
      expect(link.openedTokens, isEmpty);
    });

    test('token without update mode is rejected so no new Item can be linked', () async {
      final functions = _repairBackend(
        createLinkToken: (_) => okResponse({
          'link_token': 'link-initial-token',
          'expiration': '2026-10-03T14:00:00Z',
        }),
      );
      final link = FakePlaidLink();

      final outcome = await fakeConnectService(
        functions,
        link,
      ).reconnect(connectionId: _connectionId, locale: 'en-CA');

      expect(outcome, isA<PlaidReconnectFailed>());
      expect(link.openedTokens, isEmpty);
    });
  });

  group('initial Link regression', () {
    FakePlaidFunctions initialBackend() {
      return FakePlaidFunctions({
        'plaid-create-link-token': (_) => okResponse({
          'link_token': 'link-initial-token',
          'expiration': '2026-10-03T14:00:00Z',
        }),
        'plaid-exchange-public-token': (_) =>
            okResponse({'status': 'connected', 'connection_id': _connectionId}),
      });
    }

    test('initial Link exchanges the public token and returns the new connection', () async {
      final functions = initialBackend();
      final link = FakePlaidLink();

      final outcome = await fakeConnectService(
        functions,
        link,
      ).connect(locale: 'en-CA');

      expect(functions.functionNames, [
        'plaid-create-link-token',
        'plaid-exchange-public-token',
      ]);
      expect(functions.calls.first.body, {'locale': 'en-CA'});
      expect(
        functions.calls.last.body['public_token'],
        'public-sandbox-token',
      );
      expect(link.openedTokens, ['link-initial-token']);
      expect((outcome as PlaidConnectCompleted).connectionId, _connectionId);
    });

    test('initial and repair flows differ: only initial exchanges', () async {
      final initialFunctions = initialBackend();
      await fakeConnectService(
        initialFunctions,
        FakePlaidLink(),
      ).connect(locale: 'en-CA');

      final repairFunctions = _repairBackend();
      await fakeConnectService(
        repairFunctions,
        FakePlaidLink(),
      ).reconnect(connectionId: _connectionId, locale: 'en-CA');

      expect(
        initialFunctions.functionNames,
        contains('plaid-exchange-public-token'),
      );
      expect(
        initialFunctions.calls.first.body.containsKey('connection_id'),
        isFalse,
      );
      expect(
        repairFunctions.functionNames,
        isNot(contains('plaid-exchange-public-token')),
      );
      expect(repairFunctions.functionNames, contains('plaid-refresh-item-status'));
      expect(repairFunctions.calls.first.body['connection_id'], _connectionId);
    });

    test('initial Link cancel stays a cancel', () async {
      final functions = initialBackend();

      final outcome = await fakeConnectService(
        functions,
        FakePlaidLink(result: const PlaidLinkSessionExited()),
      ).connect(locale: 'en-CA');

      expect(outcome, isA<PlaidConnectCancelled>());
      expect(functions.functionNames, ['plaid-create-link-token']);
    });

    test('initial Link duplicate stays a duplicate', () async {
      final functions = FakePlaidFunctions({
        'plaid-create-link-token': (_) =>
            okResponse({'link_token': 'link-initial-token'}),
        'plaid-exchange-public-token': (_) =>
            okResponse({'status': 'duplicate'}),
      });

      final outcome = await fakeConnectService(
        functions,
        FakePlaidLink(),
      ).connect(locale: 'en-CA');

      expect(outcome, isA<PlaidConnectDuplicate>());
    });
  });
}
