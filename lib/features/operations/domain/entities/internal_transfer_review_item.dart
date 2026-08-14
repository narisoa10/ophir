final class InternalTransferReviewAccount {
  const InternalTransferReviewAccount({
    required this.available,
    this.id,
    this.displayName,
    this.mask,
  });

  final String? id;
  final String? displayName;
  final String? mask;
  final bool available;
}

final class InternalTransferReviewOperation {
  const InternalTransferReviewOperation({
    required this.id,
    required this.amount,
    required this.type,
    required this.occurredAt,
    required this.archived,
    this.note,
  });

  final String id;
  final String? note;
  final double amount;
  final String type;
  final DateTime occurredAt;
  final bool archived;
}

final class InternalTransferReviewItem {
  const InternalTransferReviewItem({
    required this.reconciliationId,
    required this.state,
    required this.amount,
    required this.currencyCode,
    required this.outgoingDate,
    required this.incomingDate,
    required this.outgoingAccount,
    required this.incomingAccount,
    this.outgoingOperation,
    this.incomingOperation,
    this.transferOperationId,
    this.isInconsistent = false,
    this.inconsistencyCode,
  });

  final String reconciliationId;
  final String state;
  final double amount;
  final String currencyCode;
  final DateTime outgoingDate;
  final DateTime incomingDate;
  final InternalTransferReviewAccount outgoingAccount;
  final InternalTransferReviewAccount incomingAccount;
  final InternalTransferReviewOperation? outgoingOperation;
  final InternalTransferReviewOperation? incomingOperation;

  /// Forward-compatible H1 fields; unused by H2 UI.
  final String? transferOperationId;
  final bool isInconsistent;
  final String? inconsistencyCode;
}
