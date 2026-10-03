import 'package:flutter_test/flutter_test.dart';
import 'package:ophir/core/errors/app_failure.dart';
import 'package:ophir/features/accounts/data/plaid/plaid_connect_service.dart';
import 'package:ophir/features/accounts/domain/entities/plaid_connection_health.dart';
import 'package:plaid_flutter/plaid_flutter.dart';

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
      expect((outcome as PlaidConnectDuplicate).accounts, isEmpty);
    });
  });

  group('initial Link duplicate protection (contract v2)', () {
    LinkAccount account({
      String id = 'plaid-account-1',
      String name = 'Checking',
      String? mask = '0000',
      String type = 'depository',
      String subtype = 'checking',
    }) {
      return LinkAccount(
        id: id,
        mask: mask,
        name: name,
        type: type,
        subtype: subtype,
        verificationStatus: null,
      );
    }

    FakePlaidFunctions backend(FakeFunctionHandler exchange) {
      return FakePlaidFunctions({
        'plaid-create-link-token': (_) =>
            okResponse({'link_token': 'link-initial-token'}),
        'plaid-exchange-public-token': exchange,
      });
    }

    List<Map<String, dynamic>> exchangeBodies(FakePlaidFunctions functions) {
      return [
        for (final call in functions.calls)
          if (call.functionName == 'plaid-exchange-public-token') call.body,
      ];
    }

    Future<PlaidConnectOutcome> connectWith(
      FakePlaidFunctions functions, {
      List<LinkAccount>? accounts,
    }) {
      return fakeConnectService(
        functions,
        FakePlaidLink(
          result: PlaidLinkSessionSucceeded(linkSuccess(accounts: accounts)),
        ),
      ).connect(locale: 'en-CA');
    }

    test('sends the v2 payload with account identity fields', () async {
      final functions = backend(
        (_) => okResponse({'connection_id': _connectionId}),
      );

      await connectWith(
        functions,
        accounts: [
          account(),
          account(
            id: 'plaid-account-2',
            name: 'Visa',
            mask: '4242',
            type: 'credit',
            subtype: 'credit card',
          ),
        ],
      );

      expect(exchangeBodies(functions).single, {
        'contract_version': 2,
        'public_token': 'public-sandbox-token',
        'institution_id': 'ins_1',
        'selected_accounts': [
          {
            'account_id': 'plaid-account-1',
            'name': 'Checking',
            'mask': '0000',
            'type': 'depository',
            'subtype': 'checking',
          },
          {
            'account_id': 'plaid-account-2',
            'name': 'Visa',
            'mask': '4242',
            'type': 'credit',
            'subtype': 'credit card',
          },
        ],
        'confirm_ambiguous': false,
      });
    });

    test(
      'null or blank mask is sent as null and the Link is not cancelled',
      () async {
        for (final mask in <String?>[null, '   ']) {
          final functions = backend(
            (_) => okResponse({'connection_id': _connectionId}),
          );

          final outcome = await connectWith(
            functions,
            accounts: [account(mask: mask)],
          );

          final sent = exchangeBodies(functions).single;
          final accounts = sent['selected_accounts'] as List<dynamic>;
          expect((accounts.single as Map)['mask'], isNull);
          expect(accounts.single, containsPair('mask', null));
          expect(outcome, isA<PlaidConnectCompleted>());
        }
      },
    );

    test('unusable Link metadata is a failure, never a cancel', () async {
      final functions = backend(
        (_) => okResponse({'connection_id': _connectionId}),
      );

      final outcome = await connectWith(
        functions,
        accounts: [account(id: '  ')],
      );

      expect(outcome, isA<PlaidConnectFailed>());
      expect((outcome as PlaidConnectFailed).failure, isA<ValidationFailure>());
      expect(exchangeBodies(functions), isEmpty);
    });

    test('Link error is a failure and a real exit is a cancel', () async {
      final functions = backend(
        (_) => okResponse({'connection_id': _connectionId}),
      );

      final failed = await fakeConnectService(
        functions,
        FakePlaidLink(result: const PlaidLinkSessionFailed()),
      ).connect(locale: 'en-CA');
      final exited = await fakeConnectService(
        functions,
        FakePlaidLink(result: const PlaidLinkSessionExited()),
      ).connect(locale: 'en-CA');

      expect(failed, isA<PlaidConnectFailed>());
      expect(exited, isA<PlaidConnectCancelled>());
      expect(exchangeBodies(functions), isEmpty);
    });

    test('duplicate maps decisions back to the selected accounts', () async {
      final outcome = await connectWith(
        backend(
          (_) => okResponse({
            'status': 'duplicate',
            'accounts': [
              {'index': 1, 'decision': 'disconnected_existing'},
              {'index': 0, 'decision': 'duplicate'},
            ],
          }),
        ),
        accounts: [
          account(),
          account(id: 'b', name: 'Savings', mask: null),
        ],
      );

      final accounts = (outcome as PlaidConnectDuplicate).accounts;
      expect(accounts.map((a) => a.name), ['Checking', 'Savings']);
      expect(accounts.map((a) => a.mask), ['0000', null]);
      expect(accounts.map((a) => a.decision), [
        PlaidLinkAccountDecision.duplicate,
        PlaidLinkAccountDecision.disconnectedExisting,
      ]);
    });

    test(
      'partial_duplicate, confirmation_required and disconnected_existing parse',
      () async {
        final accounts = [account(), account(id: 'b', name: 'Savings')];

        final partial = await connectWith(
          backend(
            (_) => okResponse({
              'status': 'partial_duplicate',
              'accounts': [
                {'index': 0, 'decision': 'duplicate'},
                {'index': 1, 'decision': 'new'},
              ],
            }),
          ),
          accounts: accounts,
        );
        expect(
          (partial as PlaidConnectPartialDuplicate).accounts.map(
            (a) => a.decision,
          ),
          [
            PlaidLinkAccountDecision.duplicate,
            PlaidLinkAccountDecision.newAccount,
          ],
        );

        final ambiguous = await connectWith(
          backend(
            (_) => okResponse({
              'status': 'confirmation_required',
              'accounts': [
                {'index': 0, 'decision': 'ambiguous'},
                {'index': 1, 'decision': 'new'},
              ],
            }),
          ),
          accounts: accounts,
        );
        final confirmation = ambiguous as PlaidConnectConfirmationRequired;
        expect(
          confirmation.accounts.first.decision,
          PlaidLinkAccountDecision.ambiguous,
        );
        expect(confirmation.pendingLink.publicToken, 'public-sandbox-token');

        final disconnected = await connectWith(
          backend(
            (_) => okResponse({
              'status': 'disconnected_existing',
              'accounts': [
                {'index': 0, 'decision': 'disconnected_existing'},
                {'index': 1, 'decision': 'disconnected_existing'},
              ],
            }),
          ),
          accounts: accounts,
        );
        expect(disconnected, isA<PlaidConnectDisconnectedExisting>());
      },
    );

    test('unknown status and malformed decision lists fail closed', () async {
      final malformed = <Map<String, dynamic>>[
        {'status': 'merged'},
        {'status': 'partial_duplicate'},
        {
          'status': 'partial_duplicate',
          'accounts': [
            {'index': 0, 'decision': 'duplicate'},
          ],
        },
        {
          'status': 'confirmation_required',
          'accounts': [
            {'index': 0, 'decision': 'ambiguous'},
            {'index': 0, 'decision': 'new'},
          ],
        },
        {
          'status': 'disconnected_existing',
          'accounts': [
            {'index': 0, 'decision': 'disconnected_existing'},
            {'index': 2, 'decision': 'new'},
          ],
        },
        {
          'status': 'duplicate',
          'accounts': [
            {'index': 0, 'decision': 'duplicate'},
            {'index': 1, 'decision': 'maybe'},
          ],
        },
        {'status': 'duplicate', 'accounts': 'all'},
        {'connection_id': ''},
        <String, dynamic>{},
      ];

      for (final data in malformed) {
        final outcome = await connectWith(
          backend((_) => okResponse(data)),
          accounts: [
            account(),
            account(id: 'b', name: 'Savings'),
          ],
        );

        expect(outcome, isA<PlaidConnectFailed>(), reason: '$data');
        expect((outcome as PlaidConnectFailed).failure, isA<UnknownFailure>());
      }
    });

    test(
      'server rejection and check failure are failures, not duplicates',
      () async {
        final invalid = await connectWith(
          backend((_) => throw edgeError(400, 'invalid_request')),
        );
        final checkFailed = await connectWith(
          backend((_) => throw edgeError(500, 'duplicate_check_failed')),
        );

        expect(
          (invalid as PlaidConnectFailed).failure,
          isA<ValidationFailure>(),
        );
        expect(
          (checkFailed as PlaidConnectFailed).failure,
          isA<UnknownFailure>(),
        );
      },
    );

    test(
      'confirmation resends the same Link payload with confirm_ambiguous',
      () async {
        var exchangeCount = 0;
        final functions = backend((body) {
          exchangeCount += 1;
          if (body['confirm_ambiguous'] == true) {
            return okResponse({'connection_id': _connectionId});
          }
          return okResponse({
            'status': 'confirmation_required',
            'accounts': [
              {'index': 0, 'decision': 'ambiguous'},
            ],
          });
        });
        final service = fakeConnectService(
          functions,
          FakePlaidLink(
            result: PlaidLinkSessionSucceeded(
              linkSuccess(accounts: [account(mask: null)]),
            ),
          ),
        );

        final first = await service.connect(locale: 'en-CA');
        final confirmed = await service.confirmAmbiguous(
          (first as PlaidConnectConfirmationRequired).pendingLink,
        );

        final bodies = exchangeBodies(functions);
        expect(exchangeCount, 2);
        expect(bodies.first['confirm_ambiguous'], isFalse);
        expect(bodies.last['confirm_ambiguous'], isTrue);
        expect(
          {...bodies.last}..remove('confirm_ambiguous'),
          {...bodies.first}..remove('confirm_ambiguous'),
        );
        expect(
          functions.functionNames.where((n) => n == 'plaid-create-link-token'),
          hasLength(1),
        );
        expect(
          (confirmed as PlaidConnectCompleted).connectionId,
          _connectionId,
        );
      },
    );

    test('confirmation never accepts another confirmation request', () async {
      final functions = backend(
        (_) => okResponse({
          'status': 'confirmation_required',
          'accounts': [
            {'index': 0, 'decision': 'ambiguous'},
          ],
        }),
      );
      final service = fakeConnectService(functions, FakePlaidLink());

      final first = await service.connect(locale: 'en-CA');
      final confirmed = await service.confirmAmbiguous(
        (first as PlaidConnectConfirmationRequired).pendingLink,
      );

      expect(confirmed, isA<PlaidConnectFailed>());
    });

    test(
      'confirmation still reports a duplicate found by the recheck',
      () async {
        final functions = backend((body) {
          if (body['confirm_ambiguous'] == true) {
            return okResponse({
              'status': 'duplicate',
              'accounts': [
                {'index': 0, 'decision': 'duplicate'},
              ],
            });
          }
          return okResponse({
            'status': 'confirmation_required',
            'accounts': [
              {'index': 0, 'decision': 'ambiguous'},
            ],
          });
        });
        final service = fakeConnectService(functions, FakePlaidLink());

        final first = await service.connect(locale: 'en-CA');
        final confirmed = await service.confirmAmbiguous(
          (first as PlaidConnectConfirmationRequired).pendingLink,
        );

        expect(confirmed, isA<PlaidConnectDuplicate>());
      },
    );
  });
}
