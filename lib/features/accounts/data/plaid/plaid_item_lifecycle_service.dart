import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/errors/app_failure.dart';
import '../../../../core/errors/result.dart';
import 'plaid_connect_service.dart';
import 'plaid_edge_failure.dart';

/// User Disconnect and Delete of a Plaid connection through `plaid-remove-item`.
///
/// Always sends an explicit `action`; the body without one is the legacy
/// remove contract kept on the server for older app versions.
final class PlaidItemLifecycleService {
  PlaidItemLifecycleService(SupabaseClient client)
    : this.withInvoker(
        (functionName, {required body}) =>
            client.functions.invoke(functionName, body: body),
      );

  const PlaidItemLifecycleService.withInvoker(this._invokeFunction);

  final PlaidFunctionInvoker _invokeFunction;

  /// Succeeds once the server reports the Item disconnected, including a
  /// repeated Disconnect.
  Future<Result<void>> disconnectItem(String connectionId) {
    return _run(
      connectionId: connectionId,
      action: 'disconnect',
      successStatuses: const {'disconnected', 'already_disconnected'},
    );
  }

  Future<Result<void>> deleteItem(String connectionId) {
    return _run(
      connectionId: connectionId,
      action: 'delete',
      successStatuses: const {'deleted'},
    );
  }

  Future<Result<void>> _run({
    required String connectionId,
    required String action,
    required Set<String> successStatuses,
  }) async {
    try {
      final response = await _invokeFunction(
        'plaid-remove-item',
        body: {'connection_id': connectionId, 'action': action},
      );

      final data = response.data;
      if (response.status != 200 ||
          data is! Map<String, dynamic> ||
          !successStatuses.contains(data['status'])) {
        return const Failure(UnknownFailure());
      }

      return const Success(null);
    } on FunctionException catch (exception) {
      return Failure(plaidFailureFromFunctionException(exception));
    } catch (_) {
      return const Failure(NetworkFailure());
    }
  }
}
