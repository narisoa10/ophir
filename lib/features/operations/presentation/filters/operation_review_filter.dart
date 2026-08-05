import '../../domain/entities/operation.dart';
import '../../domain/utils/operation_needs_categorization.dart';

/// Stage 1 — optional filter for operations awaiting categorization.
final class OperationReviewFilter {
  const OperationReviewFilter({required this.enabled});

  final bool enabled;

  List<Operation> apply(List<Operation> operations) {
    if (!enabled) {
      return operations;
    }

    return operations
        .where(operationNeedsCategorization)
        .toList(growable: false);
  }
}
