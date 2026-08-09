import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/errors/app_failure.dart';
import '../../../../core/errors/result.dart';

final class PlaidAccountsSyncSummary {
  const PlaidAccountsSyncSummary({
    required this.syncedAccountCount,
    this.institutionName,
  });

  final int syncedAccountCount;
  final String? institutionName;
}

final class PlaidAccountsSyncService {
  const PlaidAccountsSyncService(this._client);

  final SupabaseClient _client;

  Future<Result<PlaidAccountsSyncSummary>> syncAccounts(
    String connectionId,
  ) async {
    try {
      final response = await _client.functions.invoke(
        'plaid-sync-accounts',
        body: {'connection_id': connectionId},
      );

      final failure = _failureFromResponseStatus(response.status);
      if (failure != null) {
        return Failure(failure);
      }

      final data = response.data;
      if (data is! Map<String, dynamic>) {
        return const Failure(UnknownFailure());
      }

      final syncedAccountCount = data['synced_account_count'];
      if (syncedAccountCount is! num) {
        return const Failure(UnknownFailure());
      }

      final institutionName = data['institution_name'];

      return Success(
        PlaidAccountsSyncSummary(
          syncedAccountCount: syncedAccountCount.toInt(),
          institutionName: institutionName is String ? institutionName : null,
        ),
      );
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
    if (status >= 500) {
      return const UnknownFailure();
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
    return const UnknownFailure();
  }
}
