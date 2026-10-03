import 'package:flutter_test/flutter_test.dart';
import 'package:ophir/core/errors/app_failure.dart';
import 'package:ophir/core/errors/result.dart';
import 'package:ophir/features/accounts/data/plaid/plaid_item_lifecycle_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../support/plaid_test_fakes.dart';

void main() {
  late FakePlaidFunctions functions;
  late PlaidItemLifecycleService service;

  void respond(FakeFunctionHandler handler) {
    functions = FakePlaidFunctions({'plaid-remove-item': handler});
    service = PlaidItemLifecycleService.withInvoker(functions.invoke);
  }

  void respondStatus(String status) {
    respond((_) => okResponse({'status': status}));
  }

  AppFailure? failureOf(Result<void> result) {
    return switch (result) {
      Success() => null,
      Failure(:final failure) => failure,
    };
  }

  group('disconnectItem', () {
    test('sends connection id and the disconnect action only', () async {
      respondStatus('disconnected');

      await service.disconnectItem('item-1');

      expect(functions.functionNames, ['plaid-remove-item']);
      expect(functions.calls.single.body, {
        'connection_id': 'item-1',
        'action': 'disconnect',
      });
    });

    test('disconnected and already_disconnected are success', () async {
      for (final status in ['disconnected', 'already_disconnected']) {
        respondStatus(status);

        expect(await service.disconnectItem('item-1'), isA<Success<void>>());
      }
    });

    test('legacy removed and delete statuses are not success', () async {
      for (final status in ['removed', 'deleted', 'unexpected']) {
        respondStatus(status);

        expect(
          failureOf(await service.disconnectItem('item-1')),
          isA<UnknownFailure>(),
        );
      }
    });
  });

  group('deleteItem', () {
    test('sends connection id and the delete action only', () async {
      respondStatus('deleted');

      await service.deleteItem('item-1');

      expect(functions.calls.single.body, {
        'connection_id': 'item-1',
        'action': 'delete',
      });
    });

    test('only deleted is success', () async {
      respondStatus('deleted');
      expect(await service.deleteItem('item-1'), isA<Success<void>>());

      for (final status in [
        'removed',
        'disconnected',
        'already_disconnected',
      ]) {
        respondStatus(status);

        expect(
          failureOf(await service.deleteItem('item-1')),
          isA<UnknownFailure>(),
        );
      }
    });
  });

  group('failures', () {
    test('malformed 200 bodies are not success', () async {
      for (final data in <Object?>[null, 'deleted', <String, dynamic>{}]) {
        respond((_) => FunctionResponse(data: data, status: 200));

        expect(
          failureOf(await service.deleteItem('item-1')),
          isA<UnknownFailure>(),
        );
      }
    });

    test('connection_not_found maps to NotFoundFailure', () async {
      respond((_) => throw edgeError(404, 'connection_not_found'));

      expect(
        failureOf(await service.disconnectItem('item-1')),
        isA<NotFoundFailure>(),
      );
      expect(
        failureOf(await service.deleteItem('item-1')),
        isA<NotFoundFailure>(),
      );
    });

    test('Plaid and local lifecycle errors are failures', () async {
      for (final entry in const {
        'plaid_request_failed': 502,
        'plaid_outcome_unknown': 502,
        'local_lifecycle_failed': 500,
      }.entries) {
        respond((_) => throw edgeError(entry.value, entry.key));

        expect(
          failureOf(await service.disconnectItem('item-1')),
          isA<UnknownFailure>(),
        );
        expect(
          failureOf(await service.deleteItem('item-1')),
          isA<UnknownFailure>(),
        );
      }
    });

    test('unauthorized keeps its typed failure', () async {
      respond((_) => throw edgeError(401, 'unauthorized'));

      expect(
        failureOf(await service.deleteItem('item-1')),
        isA<UnauthorizedFailure>(),
      );
    });

    test('transport errors are network failures', () async {
      respond((_) => throw Exception('offline'));

      expect(
        failureOf(await service.disconnectItem('item-1')),
        isA<NetworkFailure>(),
      );
    });
  });
}
