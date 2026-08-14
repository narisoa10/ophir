import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/errors/app_failure.dart';
import '../../../../core/errors/result.dart';
import '../../domain/entities/internal_transfer_review_item.dart';
import '../../domain/internal_transfer_confirm_outcome.dart';
import '../../domain/repositories/internal_transfer_review_repository.dart';
import '../dto/internal_transfer_review_item_dto.dart';

/// Exact EF body for confirm. Exposed for H2 contract tests.
Map<String, dynamic> buildInternalTransferConfirmRequestBody(
  String reconciliationId,
) {
  return <String, dynamic>{'reconciliation_id': reconciliationId};
}

final class SupabaseInternalTransferReviewRepository
    implements InternalTransferReviewRepository {
  const SupabaseInternalTransferReviewRepository(this._client);

  final SupabaseClient _client;

  @override
  Future<Result<List<InternalTransferReviewItem>>> listCandidates() async {
    try {
      final data = await _client.rpc(
        'plaid_list_internal_transfer_review_items',
        params: {
          'p_states': <String>['candidate'],
        },
      );

      if (data is! List) {
        return const Failure(DatabaseFailure());
      }

      final items = <InternalTransferReviewItem>[];
      for (final row in data) {
        if (row is! Map) {
          return const Failure(DatabaseFailure());
        }
        final map = row is Map<String, dynamic>
            ? row
            : row.map((key, value) => MapEntry(key.toString(), value));
        items.add(InternalTransferReviewItemDto.fromJson(map).toEntity());
      }

      return Success(items);
    } on PostgrestException {
      return const Failure(DatabaseFailure());
    } catch (_) {
      return const Failure(UnknownFailure());
    }
  }

  @override
  Future<InternalTransferConfirmOutcome> confirm(
    String reconciliationId,
  ) async {
    try {
      final response = await _client.functions.invoke(
        'plaid-confirm-internal-transfer',
        body: buildInternalTransferConfirmRequestBody(reconciliationId),
      );

      if (response.status == 200) {
        return _successFromData(response.data);
      }

      return _outcomeFromErrorPayload(
        status: response.status,
        payload: response.data,
      );
    } on FunctionException catch (exception) {
      return _outcomeFromErrorPayload(
        status: exception.status,
        payload: exception.details,
      );
    } catch (_) {
      return const InternalTransferConfirmRetryableFailure(NetworkFailure());
    }
  }

  InternalTransferConfirmOutcome _successFromData(Object? data) {
    if (data is! Map) {
      return const InternalTransferConfirmRetryableFailure(UnknownFailure());
    }

    final map = data is Map<String, dynamic>
        ? data
        : data.map((key, value) => MapEntry(key.toString(), value));
    final status = map['status'];
    final reconciliationId = map['reconciliation_id'];
    final transferOperationId = map['transfer_operation_id'];

    if (status is! String ||
        (status != 'confirmed' && status != 'already_confirmed') ||
        reconciliationId is! String ||
        reconciliationId.isEmpty ||
        transferOperationId is! String ||
        transferOperationId.isEmpty) {
      return const InternalTransferConfirmRetryableFailure(UnknownFailure());
    }

    return InternalTransferConfirmSucceeded(
      status: status,
      reconciliationId: reconciliationId,
      transferOperationId: transferOperationId,
    );
  }

  InternalTransferConfirmOutcome _outcomeFromErrorPayload({
    required int status,
    required Object? payload,
  }) {
    final code = _errorCodeFromPayload(payload);

    if (code == 'stale_candidate') {
      return const InternalTransferConfirmStale();
    }
    if (code == 'not_found' || code == 'invalid_state' || code == 'reversed') {
      return const InternalTransferConfirmUnavailable();
    }
    if (code == 'unauthorized' || status == 401) {
      return const InternalTransferConfirmUnauthorized();
    }
    if (code == 'invalid_request' || status == 400) {
      return const InternalTransferConfirmInvalidRequest();
    }
    if (status == 409) {
      return const InternalTransferConfirmUnavailable();
    }
    if (status == 404) {
      return const InternalTransferConfirmUnavailable();
    }

    return const InternalTransferConfirmRetryableFailure(UnknownFailure());
  }

  String? _errorCodeFromPayload(Object? payload) {
    if (payload is! Map) {
      if (payload is String) {
        // Some clients stringify JSON details.
        return null;
      }
      return null;
    }

    final map = payload is Map<String, dynamic>
        ? payload
        : payload.map((key, value) => MapEntry(key.toString(), value));
    final error = map['error'];
    if (error is Map) {
      final code = error['code'];
      if (code is String && code.isNotEmpty) {
        return code;
      }
    }
    final direct = map['code'];
    if (direct is String && direct.isNotEmpty) {
      return direct;
    }
    return null;
  }
}
