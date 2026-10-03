import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/app_failure.dart';
import '../../../core/errors/result.dart';
import 'account_controller.dart';
import 'account_providers.dart';

/// Re-reads accounts, institutions and connection health from Supabase.
///
/// Database reads only: no Edge Function, Plaid or Link call is made here.
final accountsDataRefreshProvider = Provider<AccountsDataRefresh>((ref) {
  return AccountsDataRefresh(ref);
});

final class AccountsDataRefresh {
  AccountsDataRefresh(this._ref);

  final Ref _ref;
  Future<Result<void>>? _inFlight;
  Future<Result<void>>? _queuedAfterMutation;

  /// Concurrent callers share the in-flight re-read.
  ///
  /// Each re-read part replaces its provider value on success and keeps the
  /// last successful value on failure. The result is a [Failure] unless every
  /// loaded part was re-read. Parts that were never loaded are skipped: their
  /// first build already reads fresh data.
  Future<Result<void>> refresh() {
    final existing = _inFlight;
    if (existing != null) {
      return existing;
    }

    final started = _run();
    _inFlight = started;

    started.whenComplete(() {
      if (identical(_inFlight, started)) {
        _inFlight = null;
      }
    }).ignore();

    return started;
  }

  /// Re-reads after a server-side change the caller has just completed.
  ///
  /// A re-read already in flight may have read the state before that change,
  /// so it is never the answer: this waits for it and then joins the first
  /// [refresh] started afterwards. Callers arriving while that wait is
  /// pending share it, so concurrent changes cost one extra re-read.
  Future<Result<void>> refreshAfterMutation() {
    final queued = _queuedAfterMutation;
    if (queued != null) {
      return queued;
    }

    final next = _refreshAfterInFlight();
    _queuedAfterMutation = next;
    return next;
  }

  Future<Result<void>> _refreshAfterInFlight() async {
    try {
      final current = _inFlight;
      if (current != null) {
        await current;
      } else {
        // Yields once so callers in the same synchronous turn share this wait.
        await Future<void>.value();
      }
    } catch (_) {
      // Only the re-read started afterwards answers; how the earlier one
      // ended does not matter.
    }

    _queuedAfterMutation = null;
    return refresh();
  }

  Future<Result<void>> _run() async {
    final repository = _ref.read(accountRepositoryProvider);
    final loadHealth = _ref.read(plaidConnectionHealthLoaderProvider);

    final (accounts, institutions, health) = await (
      _read(
        isLoaded: _ref.exists(accountControllerProvider),
        read: repository.getAccounts,
      ),
      _read(
        isLoaded: _ref.exists(accountInstitutionsProvider),
        read: repository.getInstitutions,
      ),
      _read(
        isLoaded: _ref.exists(plaidConnectionHealthProvider),
        read: loadHealth,
      ),
    ).wait;

    if (accounts != null) {
      _ref
          .read(accountControllerProvider.notifier)
          .applyRefreshedResult(accounts);
    }
    if (institutions != null) {
      _ref
          .read(accountInstitutionsProvider.notifier)
          .applyRefreshedResult(institutions);
    }
    if (health != null) {
      _ref
          .read(plaidConnectionHealthProvider.notifier)
          .applyRefreshedResult(health);
    }

    for (final part in <Result<Object?>?>[accounts, institutions, health]) {
      if (part case Failure<Object?>(:final failure)) {
        return Failure(failure);
      }
    }

    return const Success(null);
  }

  Future<Result<T>?> _read<T>({
    required bool isLoaded,
    required Future<Result<T>> Function() read,
  }) async {
    if (!isLoaded) {
      return null;
    }

    try {
      return await read();
    } catch (_) {
      return Failure<T>(const UnknownFailure());
    }
  }
}
