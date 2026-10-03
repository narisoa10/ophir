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

    unawaited(
      started.whenComplete(() {
        if (identical(_inFlight, started)) {
          _inFlight = null;
        }
      }),
    );

    return started;
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
