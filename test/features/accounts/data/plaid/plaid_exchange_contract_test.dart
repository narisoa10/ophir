import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:ophir/core/errors/app_failure.dart';
import 'package:ophir/features/accounts/data/plaid/plaid_connect_service.dart';
import 'package:plaid_flutter/plaid_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../support/plaid_test_fakes.dart';

const _connectionId = '22222222-2222-4222-8222-222222222222';
const _exchange = 'plaid-exchange-public-token';
const _createLinkToken = 'plaid-create-link-token';

LinkAccount _account(String id, String name, String mask) {
  return LinkAccount(
    id: id,
    mask: mask,
    name: name,
    type: 'depository',
    subtype: 'checking',
    verificationStatus: null,
  );
}

final _oneAccount = [_account('plaid-account-1', 'Checking', '0000')];
final _twoAccounts = [
  _account('plaid-account-1', 'Checking', '0000'),
  _account('plaid-account-2', 'Savings', '1111'),
];

FakePlaidFunctions _backend(FakeFunctionHandler exchange) {
  return FakePlaidFunctions({
    _createLinkToken: (_) => okResponse({'link_token': 'link-initial-token'}),
    _exchange: exchange,
  });
}

Future<PlaidConnectOutcome> _connect(
  FakePlaidFunctions functions, {
  List<LinkAccount>? accounts,
  FakePlaidLink? link,
}) {
  return fakeConnectService(
    functions,
    link ??
        FakePlaidLink(
          result: PlaidLinkSessionSucceeded(linkSuccess(accounts: accounts)),
        ),
  ).connect(locale: 'en-CA');
}

int _exchangeCount(FakePlaidFunctions functions) {
  return functions.functionNames.where((name) => name == _exchange).length;
}

void main() {
  // A3 answers every stored connection the same way: a new Item, a recovered
  // lost response and idempotent_existing are all {connection_id}.
  group('A3 exchange contract: connected', () {
    test(
      'connection_id is success whatever the server did to produce it',
      () async {
        final bodies = <String, Map<String, dynamic>>{
          'created': {'connection_id': _connectionId},
          'recovered after a lost response': {'connection_id': _connectionId},
          'idempotent_existing': {'connection_id': _connectionId},
          'explicit connected status': {
            'status': 'connected',
            'connection_id': _connectionId,
          },
        };

        for (final MapEntry(key: label, value: body) in bodies.entries) {
          final functions = _backend((_) => okResponse(body));
          final link = FakePlaidLink();

          final outcome = await _connect(functions, link: link);

          expect(outcome, isA<PlaidConnectCompleted>(), reason: label);
          expect(
            (outcome as PlaidConnectCompleted).connectionId,
            _connectionId,
            reason: label,
          );
          expect(functions.functionNames, [_createLinkToken, _exchange]);
          expect(link.openedTokens, hasLength(1), reason: label);
        }
      },
    );
  });

  group('A3 exchange contract: duplicate', () {
    test('post-exchange duplicate without accounts is a duplicate', () async {
      final functions = _backend((_) => okResponse({'status': 'duplicate'}));

      final outcome = await _connect(functions, accounts: _twoAccounts);

      expect(outcome, isA<PlaidConnectDuplicate>());
      expect((outcome as PlaidConnectDuplicate).accounts, isEmpty);
      expect(_exchangeCount(functions), 1);
    });

    test('Level 1 and Level 2 duplicates are the same outcome', () async {
      final level1 = await _connect(
        _backend(
          (_) => okResponse({
            'status': 'duplicate',
            'accounts': [
              {'index': 0, 'decision': 'duplicate'},
            ],
          }),
        ),
        accounts: _oneAccount,
      );
      final level2 = await _connect(
        _backend((_) => okResponse({'status': 'duplicate'})),
        accounts: _oneAccount,
      );

      expect(level1, isA<PlaidConnectDuplicate>());
      expect(level2, isA<PlaidConnectDuplicate>());
      expect((level1 as PlaidConnectDuplicate).accounts, hasLength(1));
      expect((level2 as PlaidConnectDuplicate).accounts, isEmpty);
    });

    test('the Level 2 result does not depend on the Link selection', () async {
      for (final accounts in [_oneAccount, _twoAccounts]) {
        final duplicate = await _connect(
          _backend((_) => okResponse({'status': 'duplicate'})),
          accounts: accounts,
        );
        final connected = await _connect(
          _backend((_) => okResponse({'connection_id': _connectionId})),
          accounts: accounts,
        );

        expect(duplicate, isA<PlaidConnectDuplicate>());
        expect(connected, isA<PlaidConnectCompleted>());
      }
    });
  });

  group('A3 exchange contract: failures', () {
    test('every A3 error is a failure and the exchange is sent once', () async {
      final errors = <(int, String), Type>{
        (500, 'persist_failed'): UnknownFailure,
        (502, 'plaid_request_failed'): UnknownFailure,
        (500, 'duplicate_check_failed'): UnknownFailure,
        (500, 'plaid_config_missing'): UnknownFailure,
        (500, 'supabase_config_missing'): UnknownFailure,
        (400, 'invalid_request'): ValidationFailure,
        (401, 'unauthorized'): UnauthorizedFailure,
      };

      for (final MapEntry(key: (status, code), value: failureType)
          in errors.entries) {
        final functions = _backend((_) => throw edgeError(status, code));
        final link = FakePlaidLink();

        final outcome = await _connect(functions, link: link);

        expect(outcome, isA<PlaidConnectFailed>(), reason: code);
        expect(
          (outcome as PlaidConnectFailed).failure.runtimeType,
          failureType,
          reason: code,
        );
        expect(functions.functionNames, [_createLinkToken, _exchange]);
        expect(link.openedTokens, hasLength(1), reason: code);
      }
    });

    test(
      'a lost exchange response is a network failure, never retried',
      () async {
        for (final error in <Object>[
          const SocketException('connection reset'),
          TimeoutException('no response'),
          StateError('unexpected'),
        ]) {
          final functions = _backend((_) => throw error);

          final outcome = await _connect(functions);

          expect(outcome, isA<PlaidConnectFailed>(), reason: '$error');
          expect(
            (outcome as PlaidConnectFailed).failure,
            isA<NetworkFailure>(),
            reason: '$error',
          );
          expect(_exchangeCount(functions), 1, reason: '$error');
        }
      },
    );

    test('a malformed success response never becomes a connection', () async {
      final responses = <FunctionResponse>[
        FunctionResponse(data: '', status: 200),
        FunctionResponse(data: 'connected', status: 200),
        FunctionResponse(data: null, status: 200),
        FunctionResponse(data: <Object?>[], status: 200),
        FunctionResponse(data: <String, dynamic>{}, status: 200),
        okResponse({'ok': true}),
        okResponse({'connection_id': 7}),
        okResponse({'connection_id': ''}),
        okResponse({'connection_id': null}),
        okResponse({'status': 'connected'}),
        okResponse({'status': 'created', 'connection_id': _connectionId}),
        okResponse({'status': 'duplicate', 'accounts': 'all'}),
        FunctionResponse(data: {'connection_id': _connectionId}, status: 201),
        FunctionResponse(data: '', status: 204),
      ];

      for (final response in responses) {
        final functions = _backend((_) => response);

        final outcome = await _connect(functions);

        expect(
          outcome,
          isA<PlaidConnectFailed>(),
          reason: '${response.status} ${response.data}',
        );
        expect(_exchangeCount(functions), 1);
      }
    });
  });

  // Runs the real supabase FunctionsClient against a loopback server, so empty
  // and invalid bodies reach the service exactly as they would in the app.
  group('A3 exchange contract over HTTP', () {
    late HttpServer server;
    late FunctionsClient client;
    late List<(String, Map<String, dynamic>)> requests;
    late void Function(HttpResponse response) respond;

    setUp(() async {
      requests = [];
      server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      server.listen((request) async {
        final body = await utf8.decodeStream(request);
        requests.add((
          request.method,
          jsonDecode(body) as Map<String, dynamic>,
        ));
        respond(request.response);
        await request.response.close();
      });
      client = FunctionsClient(
        'http://${server.address.host}:${server.port}/functions/v1',
        const {},
      );
    });

    tearDown(() async {
      await client.dispose();
      await server.close(force: true);
    });

    PlaidConnectService service(FunctionsClient functions) {
      return PlaidConnectService.withDependencies(
        invokeFunction: (functionName, {required body}) {
          if (functionName == _createLinkToken) {
            return Future.value(okResponse({'link_token': 'link-token'}));
          }
          return functions.invoke(functionName, body: body);
        },
        launchLink: FakePlaidLink().launch,
      );
    }

    void Function(HttpResponse) reply(
      int status,
      String contentType,
      String body,
    ) {
      return (response) {
        response.statusCode = status;
        response.headers.set(HttpHeaders.contentTypeHeader, contentType);
        response.write(body);
      };
    }

    const json = 'application/json';

    test('connection_id and duplicate bodies map to their outcomes', () async {
      respond = reply(200, json, jsonEncode({'connection_id': _connectionId}));
      final connected = await service(client).connect(locale: 'en-CA');

      respond = reply(200, json, jsonEncode({'status': 'duplicate'}));
      final duplicate = await service(client).connect(locale: 'en-CA');

      expect((connected as PlaidConnectCompleted).connectionId, _connectionId);
      expect((duplicate as PlaidConnectDuplicate).accounts, isEmpty);
      expect(requests.map((r) => r.$1), ['POST', 'POST']);
      expect(requests.map((r) => r.$2['contract_version']), [2, 2]);
    });

    test('empty, invalid and non-JSON 200 bodies are failures', () async {
      final bodies = <(String, String)>[
        (json, ''),
        (json, '{"connection_id":'),
        ('text/plain', 'connection_id=$_connectionId'),
        ('text/html', '<html>OK</html>'),
      ];

      for (final (contentType, body) in bodies) {
        requests.clear();
        respond = reply(200, contentType, body);

        final outcome = await service(client).connect(locale: 'en-CA');

        expect(
          outcome,
          isA<PlaidConnectFailed>(),
          reason: '$contentType $body',
        );
        expect(requests, hasLength(1), reason: '$contentType $body');
      }
    });

    test(
      'error statuses with expected or malformed bodies are sent once',
      () async {
        final replies = <(int, String, String)>[
          (
            500,
            json,
            jsonEncode({
              'error': {'code': 'persist_failed'},
            }),
          ),
          (
            502,
            json,
            jsonEncode({
              'error': {'code': 'plaid_request_failed'},
            }),
          ),
          (500, json, '{"error":'),
          (502, 'text/html', '<html>Bad Gateway</html>'),
          (503, 'text/plain', ''),
          (504, json, ''),
        ];

        for (final (status, contentType, body) in replies) {
          requests.clear();
          respond = reply(status, contentType, body);

          final outcome = await service(client).connect(locale: 'en-CA');

          expect(outcome, isA<PlaidConnectFailed>(), reason: '$status $body');
          expect(
            (outcome as PlaidConnectFailed).failure,
            isA<UnknownFailure>(),
            reason: '$status $body',
          );
          expect(requests, hasLength(1), reason: '$status $body');
        }
      },
    );

    test('an unreachable server is a network failure', () async {
      final closed = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      final port = closed.port;
      await closed.close(force: true);
      final unreachable = FunctionsClient(
        'http://${InternetAddress.loopbackIPv4.address}:$port/functions/v1',
        const {},
      );
      addTearDown(unreachable.dispose);

      final outcome = await service(unreachable).connect(locale: 'en-CA');

      expect(outcome, isA<PlaidConnectFailed>());
      expect((outcome as PlaidConnectFailed).failure, isA<NetworkFailure>());
    });
  });
}
