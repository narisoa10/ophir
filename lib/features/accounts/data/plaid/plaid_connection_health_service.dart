import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/errors/app_failure.dart';
import '../../../../core/errors/result.dart';
import '../../domain/entities/plaid_connection_health.dart';
import '../dto/plaid_connection_health_dto.dart';

final class PlaidConnectionHealthService {
  const PlaidConnectionHealthService(this._client);

  final SupabaseClient _client;

  Future<Result<List<PlaidConnectionHealth>>> loadHealth() async {
    if (_client.auth.currentUser == null) {
      return const Failure(UnauthorizedFailure());
    }

    try {
      final data = await _client.rpc('plaid_list_connection_health');
      if (data is! List) {
        return const Failure(UnknownFailure());
      }

      final health = <PlaidConnectionHealth>[];
      for (final row in data) {
        if (row is! Map<String, dynamic>) {
          continue;
        }
        final parsed = plaidConnectionHealthFromJson(row);
        if (parsed != null) {
          health.add(parsed);
        }
      }

      return Success(List.unmodifiable(health));
    } on PostgrestException {
      return const Failure(DatabaseFailure());
    } catch (_) {
      return const Failure(UnknownFailure());
    }
  }
}
