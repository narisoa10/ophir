import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ophir/core/errors/app_failure.dart';
import 'package:ophir/core/errors/result.dart';
import 'package:ophir/features/operations/controller/internal_transfer_review_providers.dart';
import 'package:ophir/features/operations/controller/operation_providers.dart';
import 'package:ophir/features/operations/domain/entities/internal_transfer_review_item.dart';
import 'package:ophir/features/operations/domain/internal_transfer_confirm_outcome.dart';
import 'package:ophir/features/operations/domain/repositories/internal_transfer_review_repository.dart';

void main() {
  final sampleItem = InternalTransferReviewItem(
    reconciliationId: 'recon-1',
    state: 'candidate',
    amount: 50,
    currencyCode: 'USD',
    outgoingDate: DateTime(2026, 8, 14),
    incomingDate: DateTime(2026, 8, 14),
    outgoingAccount: const InternalTransferReviewAccount(
      id: 'a',
      displayName: 'From',
      available: true,
    ),
    incomingAccount: const InternalTransferReviewAccount(
      id: 'b',
      displayName: 'To',
      available: true,
    ),
  );

  ProviderContainer containerWith(InternalTransferReviewRepository repo) {
    return ProviderContainer(
      overrides: [
        internalTransferReviewRepositoryProvider.overrideWithValue(repo),
        operationRemoteSyncProvider.overrideWith((ref) {
          return () async => const Success(null);
        }),
      ],
    );
  }

  test('H2-3 review state loads candidates', () async {
    final repo = _FakeReviewRepository(candidates: [sampleItem]);
    final container = containerWith(repo);
    addTearDown(container.dispose);

    await container.read(internalTransferReviewProvider.notifier).refresh();
    final state = container.read(internalTransferReviewProvider);

    expect(state.isLoading, isFalse);
    expect(state.loadFailure, isNull);
    expect(state.candidates, hasLength(1));
    expect(state.showBanner, isTrue);
  });

  test(
    'H2-4 review load failure keeps empty candidates and no banner',
    () async {
      final repo = _FakeReviewRepository(
        listResult: const Failure(DatabaseFailure()),
      );
      final container = containerWith(repo);
      addTearDown(container.dispose);

      await container.read(internalTransferReviewProvider.notifier).refresh();
      final state = container.read(internalTransferReviewProvider);

      expect(state.loadFailure, isA<DatabaseFailure>());
      expect(state.candidates, isEmpty);
      expect(state.showBanner, isFalse);
    },
  );

  test('H2-12 confirm loading prevents duplicate call', () async {
    final repo = _FakeReviewRepository(
      candidates: [sampleItem],
      confirmDelay: const Duration(milliseconds: 40),
    );
    final container = containerWith(repo);
    addTearDown(container.dispose);

    await container.read(internalTransferReviewProvider.notifier).refresh();
    final first = container
        .read(internalTransferReviewProvider.notifier)
        .confirm('recon-1');
    final second = await container
        .read(internalTransferReviewProvider.notifier)
        .confirm('recon-1');

    expect(
      container.read(internalTransferReviewProvider).confirmingReconciliationId,
      'recon-1',
    );
    expect(second, isA<InternalTransferConfirmRetryableFailure>());
    await first;
    expect(repo.confirmCalls, 1);
    expect(
      container.read(internalTransferReviewProvider).confirmingReconciliationId,
      isNull,
    );
  });

  test('H2-13 confirmed uses confirm → ops sync → review refresh', () async {
    final order = <String>[];
    final repo = _FakeReviewRepository(
      candidates: [sampleItem],
      confirmOutcome: const InternalTransferConfirmSucceeded(
        status: 'confirmed',
        reconciliationId: 'recon-1',
        transferOperationId: 'transfer-1',
      ),
      onConfirm: () => order.add('confirm'),
      onList: () => order.add('list'),
    );
    final container = ProviderContainer(
      overrides: [
        internalTransferReviewRepositoryProvider.overrideWithValue(repo),
        operationRemoteSyncProvider.overrideWith((ref) {
          return () async {
            order.add('ops-sync');
            return const Success(null);
          };
        }),
      ],
    );
    addTearDown(container.dispose);

    await container.read(internalTransferReviewProvider.notifier).refresh();
    order.clear();

    await container
        .read(internalTransferReviewProvider.notifier)
        .confirm('recon-1');

    expect(order, ['confirm', 'ops-sync', 'list']);
  });

  test('H2-14 already_confirmed uses success sequence', () async {
    final order = <String>[];
    final repo = _FakeReviewRepository(
      candidates: [sampleItem],
      confirmOutcome: const InternalTransferConfirmSucceeded(
        status: 'already_confirmed',
        reconciliationId: 'recon-1',
        transferOperationId: 'transfer-1',
      ),
      onConfirm: () => order.add('confirm'),
      onList: () => order.add('list'),
    );
    final container = ProviderContainer(
      overrides: [
        internalTransferReviewRepositoryProvider.overrideWithValue(repo),
        operationRemoteSyncProvider.overrideWith((ref) {
          return () async {
            order.add('ops-sync');
            return const Success(null);
          };
        }),
      ],
    );
    addTearDown(container.dispose);

    await container.read(internalTransferReviewProvider.notifier).refresh();
    order.clear();
    final outcome = await container
        .read(internalTransferReviewProvider.notifier)
        .confirm('recon-1');

    expect(outcome, isA<InternalTransferConfirmSucceeded>());
    expect(
      (outcome as InternalTransferConfirmSucceeded).status,
      'already_confirmed',
    );
    expect(order, ['confirm', 'ops-sync', 'list']);
  });

  test('H2-15 stale_candidate refreshes without ops sync', () async {
    final order = <String>[];
    final repo = _FakeReviewRepository(
      candidates: [sampleItem],
      confirmOutcome: const InternalTransferConfirmStale(),
      onConfirm: () => order.add('confirm'),
      onList: () => order.add('list'),
    );
    final container = ProviderContainer(
      overrides: [
        internalTransferReviewRepositoryProvider.overrideWithValue(repo),
        operationRemoteSyncProvider.overrideWith((ref) {
          return () async {
            order.add('ops-sync');
            return const Success(null);
          };
        }),
      ],
    );
    addTearDown(container.dispose);

    await container.read(internalTransferReviewProvider.notifier).refresh();
    order.clear();
    final outcome = await container
        .read(internalTransferReviewProvider.notifier)
        .confirm('recon-1');

    expect(outcome, isA<InternalTransferConfirmStale>());
    expect(order, ['confirm', 'list']);
  });

  test(
    'H2-16 network failure keeps candidates and clears confirming',
    () async {
      final repo = _FakeReviewRepository(
        candidates: [sampleItem],
        confirmOutcome: const InternalTransferConfirmRetryableFailure(
          NetworkFailure(),
        ),
      );
      final container = containerWith(repo);
      addTearDown(container.dispose);

      await container.read(internalTransferReviewProvider.notifier).refresh();
      await container
          .read(internalTransferReviewProvider.notifier)
          .confirm('recon-1');
      final state = container.read(internalTransferReviewProvider);

      expect(state.candidates, hasLength(1));
      expect(state.confirmingReconciliationId, isNull);
      expect(state.showBanner, isTrue);
    },
  );

  test('H2-5 banner hidden when zero via showBanner', () async {
    final repo = _FakeReviewRepository(candidates: const []);
    final container = containerWith(repo);
    addTearDown(container.dispose);

    await container.read(internalTransferReviewProvider.notifier).refresh();
    expect(container.read(internalTransferReviewProvider).showBanner, isFalse);
  });

  test('H2-6 banner displays candidate count via showBanner', () async {
    final repo = _FakeReviewRepository(candidates: [sampleItem, sampleItem]);
    final container = containerWith(repo);
    addTearDown(container.dispose);

    await container.read(internalTransferReviewProvider.notifier).refresh();
    final state = container.read(internalTransferReviewProvider);
    expect(state.showBanner, isTrue);
    expect(state.candidates.length, 2);
  });

  test(
    'dispose during in-flight refresh does not touch Ref after dispose',
    () async {
      final listStarted = Completer<void>();
      final listCompleter =
          Completer<Result<List<InternalTransferReviewItem>>>();
      final repo = _FakeReviewRepository(
        listCompleter: listCompleter,
        onList: () {
          if (!listStarted.isCompleted) {
            listStarted.complete();
          }
        },
      );
      final container = containerWith(repo);

      // Mount provider → build schedules fire-and-forget refresh.
      container.read(internalTransferReviewProvider);
      await listStarted.future;

      container.dispose();

      // Completing after dispose must not throw UnmountedRefException.
      listCompleter.complete(const Success(<InternalTransferReviewItem>[]));
      await Future<void>.delayed(Duration.zero);
    },
  );
}

final class _FakeReviewRepository implements InternalTransferReviewRepository {
  _FakeReviewRepository({
    List<InternalTransferReviewItem>? candidates,
    this.listResult,
    this.listCompleter,
    this.confirmOutcome = const InternalTransferConfirmSucceeded(
      status: 'confirmed',
      reconciliationId: 'recon-1',
      transferOperationId: 'transfer-1',
    ),
    this.confirmDelay,
    this.onConfirm,
    this.onList,
  }) : _candidates = candidates ?? const [];

  final List<InternalTransferReviewItem> _candidates;
  final Result<List<InternalTransferReviewItem>>? listResult;
  final Completer<Result<List<InternalTransferReviewItem>>>? listCompleter;
  final InternalTransferConfirmOutcome confirmOutcome;
  final Duration? confirmDelay;
  final void Function()? onConfirm;
  final void Function()? onList;

  int confirmCalls = 0;

  @override
  Future<Result<List<InternalTransferReviewItem>>> listCandidates() async {
    onList?.call();
    final completer = listCompleter;
    if (completer != null) {
      return completer.future;
    }
    return listResult ?? Success(_candidates);
  }

  @override
  Future<InternalTransferConfirmOutcome> confirm(
    String reconciliationId,
  ) async {
    confirmCalls += 1;
    onConfirm?.call();
    final delay = confirmDelay;
    if (delay != null) {
      await Future<void>.delayed(delay);
    }
    return confirmOutcome;
  }
}
