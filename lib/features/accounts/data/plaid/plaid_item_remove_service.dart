import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/errors/app_failure.dart';
import '../../../../core/errors/result.dart';

final class PlaidItemRemoveService {
  const PlaidItemRemoveService(this._client);

  final SupabaseClient _client;

  Future<Result<void>> removeItem(String connectionId) async {
    try {
      final response = await _client.functions.invoke(
        'plaid-remove-item',
        body: {'connection_id': connectionId},
      );

      final failure = _failureFromResponseStatus(response.status);
      if (failure != null) {
        return Failure(failure);
      }

      final data = response.data;
      if (data is! Map<String, dynamic> || data['status'] != 'removed') {
        return const Failure(UnknownFailure());
      }

      return const Success(null);
    } on FunctionException catch (exception) {
      return Failure(_failureFromFunctionException(exception));
    } catch (_) {
      return const Failure(NetworkFailure());
    }
  }

  AppFailure? _failureFromResponseStatus(int status) {
    if (status == 200) {
      return null;
    }
    if (status == 401) {
      return const UnauthorizedFailure();
    }
    if (status == 400) {
      return const ValidationFailure();
    }
    if (status == 404 || status == 403) {
      return const NotFoundFailure();
    }
    return const UnknownFailure();
  }

  AppFailure _failureFromFunctionException(FunctionException exception) {
    final status = exception.status;
    if (status == 401) {
      return const UnauthorizedFailure();
    }
    if (status == 400) {
      return const ValidationFailure();
    }
    if (status == 404 || status == 403) {
      return const NotFoundFailure();
    }
    return const UnknownFailure();
  }
}
