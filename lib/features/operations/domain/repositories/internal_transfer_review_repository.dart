import '../../../../core/errors/result.dart';
import '../entities/internal_transfer_review_item.dart';
import '../internal_transfer_confirm_outcome.dart';

abstract interface class InternalTransferReviewRepository {
  Future<Result<List<InternalTransferReviewItem>>> listCandidates();

  Future<InternalTransferConfirmOutcome> confirm(String reconciliationId);
}
