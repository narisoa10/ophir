import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/errors/app_failure.dart';
import '../../../core/errors/result.dart';
import '../data/repositories/supabase_internal_transfer_review_repository.dart';
import '../domain/entities/internal_transfer_review_item.dart';
import '../domain/internal_transfer_confirm_outcome.dart';
import '../domain/repositories/internal_transfer_review_repository.dart';
import 'operation_providers.dart';

final internalTransferReviewRepositoryProvider =
    Provider<InternalTransferReviewRepository>((ref) {
      return SupabaseInternalTransferReviewRepository(Supabase.instance.client);
    });

final internalTransferReviewProvider =
    NotifierProvider<
      InternalTransferReviewController,
      InternalTransferReviewState
    >(InternalTransferReviewController.new);

/// Observable review state: list load + confirming id live in [state].
final class InternalTransferReviewState {
  const InternalTransferReviewState({
    this.isLoading = false,
    this.candidates = const [],
    this.loadFailure,
    this.confirmingReconciliationId,
  });

  final bool isLoading;
  final List<InternalTransferReviewItem> candidates;
  final AppFailure? loadFailure;
  final String? confirmingReconciliationId;

  bool get showBanner =>
      !isLoading && loadFailure == null && candidates.isNotEmpty;

  bool isConfirming(String reconciliationId) =>
      confirmingReconciliationId == reconciliationId;

  bool get hasInFlightConfirm => confirmingReconciliationId != null;

  InternalTransferReviewState copyWith({
    bool? isLoading,
    List<InternalTransferReviewItem>? candidates,
    AppFailure? loadFailure,
    bool clearLoadFailure = false,
    String? confirmingReconciliationId,
    bool clearConfirming = false,
  }) {
    return InternalTransferReviewState(
      isLoading: isLoading ?? this.isLoading,
      candidates: candidates ?? this.candidates,
      loadFailure: clearLoadFailure ? null : (loadFailure ?? this.loadFailure),
      confirmingReconciliationId: clearConfirming
          ? null
          : (confirmingReconciliationId ?? this.confirmingReconciliationId),
    );
  }
}

final class InternalTransferReviewController
    extends Notifier<InternalTransferReviewState> {
  /// Monotonic token so an older in-flight [refresh] cannot overwrite a newer one.
  int _refreshGeneration = 0;

  @override
  InternalTransferReviewState build() {
    // Fire-and-forget initial load (Riverpod 3: guard with ref.mounted after gaps).
    Future<void>(() async {
      if (!ref.mounted) {
        return;
      }
      await refresh();
    });
    return const InternalTransferReviewState(isLoading: true);
  }

  Future<void> refresh() async {
    if (!ref.mounted) {
      return;
    }

    final generation = ++_refreshGeneration;
    final confirming = state.confirmingReconciliationId;
    state = InternalTransferReviewState(
      isLoading: true,
      candidates: state.candidates,
      loadFailure: null,
      confirmingReconciliationId: confirming,
    );

    final repository = ref.read(internalTransferReviewRepositoryProvider);
    final result = await repository.listCandidates();

    if (!ref.mounted || generation != _refreshGeneration) {
      return;
    }

    if (result case Success<List<InternalTransferReviewItem>>(:final value)) {
      state = InternalTransferReviewState(
        candidates: value,
        confirmingReconciliationId: confirming,
      );
      return;
    }

    if (result case Failure<List<InternalTransferReviewItem>>(:final failure)) {
      state = InternalTransferReviewState(
        loadFailure: failure,
        confirmingReconciliationId: confirming,
      );
    }
  }

  Future<InternalTransferConfirmOutcome> confirm(
    String reconciliationId,
  ) async {
    if (!ref.mounted) {
      return const InternalTransferConfirmRetryableFailure(UnknownFailure());
    }

    if (state.hasInFlightConfirm) {
      return const InternalTransferConfirmRetryableFailure(UnknownFailure());
    }

    state = state.copyWith(confirmingReconciliationId: reconciliationId);

    final repository = ref.read(internalTransferReviewRepositoryProvider);
    final outcome = await repository.confirm(reconciliationId);

    if (!ref.mounted) {
      return outcome;
    }

    switch (outcome) {
      case InternalTransferConfirmSucceeded():
        final sync = ref.read(operationRemoteSyncProvider);
        await sync();
        if (!ref.mounted) {
          return outcome;
        }
        await refresh();
        if (!ref.mounted) {
          return outcome;
        }
        state = state.copyWith(clearConfirming: true);
        return outcome;
      case InternalTransferConfirmStale():
      case InternalTransferConfirmUnavailable():
        await refresh();
        if (!ref.mounted) {
          return outcome;
        }
        state = state.copyWith(clearConfirming: true);
        return outcome;
      case InternalTransferConfirmUnauthorized():
      case InternalTransferConfirmInvalidRequest():
      case InternalTransferConfirmRetryableFailure():
        state = state.copyWith(clearConfirming: true);
        return outcome;
    }
  }
}
