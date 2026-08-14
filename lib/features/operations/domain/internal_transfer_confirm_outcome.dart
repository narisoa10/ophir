import '../../../../core/errors/app_failure.dart';

sealed class InternalTransferConfirmOutcome {
  const InternalTransferConfirmOutcome();
}

final class InternalTransferConfirmSucceeded
    extends InternalTransferConfirmOutcome {
  const InternalTransferConfirmSucceeded({
    required this.status,
    required this.reconciliationId,
    required this.transferOperationId,
  });

  /// `confirmed` or `already_confirmed`.
  final String status;
  final String reconciliationId;
  final String transferOperationId;
}

final class InternalTransferConfirmStale
    extends InternalTransferConfirmOutcome {
  const InternalTransferConfirmStale();
}

final class InternalTransferConfirmUnavailable
    extends InternalTransferConfirmOutcome {
  const InternalTransferConfirmUnavailable();
}

final class InternalTransferConfirmUnauthorized
    extends InternalTransferConfirmOutcome {
  const InternalTransferConfirmUnauthorized();
}

final class InternalTransferConfirmInvalidRequest
    extends InternalTransferConfirmOutcome {
  const InternalTransferConfirmInvalidRequest();
}

final class InternalTransferConfirmRetryableFailure
    extends InternalTransferConfirmOutcome {
  const InternalTransferConfirmRetryableFailure(this.failure);

  final AppFailure failure;
}
