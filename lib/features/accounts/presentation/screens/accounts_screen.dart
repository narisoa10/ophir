import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/errors/app_failure.dart';
import '../../../../core/errors/app_failure_localization.dart';
import '../../../../core/errors/result.dart';
import '../../../../core/localization/generated/app_localizations.dart';
import '../../../../core/theme_v1/app_colors.dart';
import '../../../../core/theme_v1/app_dimensions.dart';
import '../../../../core/theme_v1/app_radius.dart';
import '../../../../core/theme_v1/app_spacing.dart';
import '../../../../core/theme_v1/app_theme_colors.dart';
import '../../../../core/theme_v1/app_typography.dart';
import '../../../../core/widgets/app_compact_switch.dart';
import '../../controller/account_controller.dart';
import '../../controller/account_providers.dart';
import '../../controller/accounts_data_refresh.dart';
import '../../data/plaid/plaid_accounts_sync_service.dart';
import '../../data/plaid/plaid_connect_service.dart';
import '../../domain/entities/account.dart';
import '../../domain/entities/institution.dart';
import '../../domain/entities/plaid_connection_health.dart';
import '../adapters/account_adapter.dart';
import '../widgets/account_list_tile.dart';
import '../widgets/accounts_empty_state.dart';

class AccountsScreen extends ConsumerStatefulWidget {
  const AccountsScreen({super.key});

  @override
  ConsumerState<AccountsScreen> createState() => _AccountsScreenState();
}

class _AccountsScreenState extends ConsumerState<AccountsScreen> {
  bool _isConnecting = false;
  final Set<String> _expandedBankGroupKeys = <String>{};
  final Set<String> _syncingConnectionIds = <String>{};
  // Disconnect or Delete in progress; at most one action per connection.
  final Set<String> _lifecycleConnectionIds = <String>{};
  final Set<String> _reconnectingConnectionIds = <String>{};
  // Sync just reported item_login_required; shown until the server confirms
  // the Item is active again, even if the health reload has not landed yet.
  final Set<String> _syncLoginRequiredConnectionIds = <String>{};
  // update mode is not possible for these Items; reconnect is not offered again.
  final Set<String> _reconnectUnavailableConnectionIds = <String>{};
  late final AppLifecycleListener _lifecycleListener;

  @override
  void initState() {
    super.initState();
    _lifecycleListener = AppLifecycleListener(
      onResume: _refreshAccountsDataOnResume,
    );
    // No-op on the first entry: the account providers are created by build,
    // whose initial load is the only read.
    unawaited(ref.read(accountsDataRefreshProvider).refresh());
  }

  @override
  void dispose() {
    _lifecycleListener.dispose();
    super.dispose();
  }

  // Closing native Plaid Link also resumes the app; the Link flows refresh
  // their own state when they finish.
  bool get _isPlaidLinkFlowActive =>
      _isConnecting || _reconnectingConnectionIds.isNotEmpty;

  void _refreshAccountsDataOnResume() {
    // A Disconnect or Delete re-reads once it completes; a re-read started
    // while it runs could only show the state before it.
    if (!mounted ||
        _isPlaidLinkFlowActive ||
        _lifecycleConnectionIds.isNotEmpty) {
      return;
    }

    unawaited(ref.read(accountsDataRefreshProvider).refresh());
  }

  bool _isConnectionBusy(String connectionId) {
    return _syncingConnectionIds.contains(connectionId) ||
        _lifecycleConnectionIds.contains(connectionId) ||
        _reconnectingConnectionIds.contains(connectionId);
  }

  bool _isDisconnected(String connectionId) {
    final health = _healthByConnectionId(
      ref.read(plaidConnectionHealthProvider),
    )[connectionId];
    return health?.isDisconnected ?? false;
  }

  Future<void> _refreshAfterMutation() {
    return ref.read(accountsDataRefreshProvider).refreshAfterMutation();
  }

  Future<void> _connectBank() async {
    if (_isConnecting) {
      return;
    }

    setState(() => _isConnecting = true);

    try {
      final locale = Localizations.localeOf(context).toLanguageTag();
      final service = ref.read(plaidConnectServiceProvider);
      var selectAgain = true;
      while (selectAgain) {
        final outcome = await service.connect(locale: locale);

        if (!mounted) {
          return;
        }

        selectAgain = await _handleConnectOutcome(service, outcome);
      }
    } finally {
      if (mounted) {
        setState(() => _isConnecting = false);
      }
    }
  }

  /// Returns true when the user asked to choose accounts in Link again.
  Future<bool> _handleConnectOutcome(
    PlaidConnectService service,
    PlaidConnectOutcome outcome,
  ) async {
    switch (outcome) {
      case PlaidConnectCompleted(:final connectionId):
        await _syncConnectedAccounts(connectionId);
      case PlaidConnectDuplicate(:final accounts):
        await _showDuplicateConnectionDialog(accounts);
      case PlaidConnectPartialDuplicate(:final accounts):
        return _showPartialDuplicateDialog(accounts);
      case PlaidConnectConfirmationRequired(
        :final accounts,
        :final pendingLink,
      ):
        final choice = await _showAmbiguousAccountsDialog(accounts);
        if (choice != _AmbiguousAccountChoice.differentAccount || !mounted) {
          return false;
        }
        final confirmedOutcome = await service.confirmAmbiguous(pendingLink);
        if (!mounted) {
          return false;
        }
        return _handleConnectOutcome(service, confirmedOutcome);
      case PlaidConnectDisconnectedExisting(:final accounts):
        await _showDisconnectedExistingDialog(accounts);
      case PlaidConnectCancelled():
        break;
      case PlaidConnectFailed(:final failure):
        final l10n = AppLocalizations.of(context);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(failure.localized(l10n))));
    }
    return false;
  }

  Future<void> _showDuplicateConnectionDialog(
    List<PlaidLinkAccountReview> accounts,
  ) async {
    final l10n = AppLocalizations.of(context);
    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(l10n.accountsDuplicateConnectionDialogTitle),
          content: _linkReviewContent(
            l10n,
            l10n.accountsDuplicateConnectionDialogBody,
            accounts,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: Text(l10n.accountsDuplicateConnectionDialogAction),
            ),
          ],
        );
      },
    );
  }

  Future<bool> _showPartialDuplicateDialog(
    List<PlaidLinkAccountReview> accounts,
  ) async {
    final l10n = AppLocalizations.of(context);
    final existing = [
      for (final account in accounts)
        if (account.decision == PlaidLinkAccountDecision.duplicate ||
            account.decision == PlaidLinkAccountDecision.disconnectedExisting)
          account,
    ];
    final selectAgain = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(l10n.accountsPartialDuplicateDialogTitle),
          content: _linkReviewContent(
            l10n,
            l10n.accountsPartialDuplicateDialogBody,
            existing,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: Text(l10n.accountsPartialDuplicateDialogClose),
            ),
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: Text(l10n.accountsPartialDuplicateDialogSelectAgain),
            ),
          ],
        );
      },
    );
    return selectAgain ?? false;
  }

  /// Returns null when the dialog is dismissed: nothing is connected.
  Future<_AmbiguousAccountChoice?> _showAmbiguousAccountsDialog(
    List<PlaidLinkAccountReview> accounts,
  ) {
    final l10n = AppLocalizations.of(context);
    final ambiguous = [
      for (final account in accounts)
        if (account.decision == PlaidLinkAccountDecision.ambiguous) account,
    ];
    final similarCount = ambiguous.fold<int>(
      0,
      (count, account) => count + account.similarAccounts.length,
    );
    final count = similarCount > 0 ? similarCount : 1;
    final anyMask = ambiguous.any(
      (account) =>
          account.mask != null &&
          account.similarAccounts.any((similar) => similar.mask != null),
    );

    return showDialog<_AmbiguousAccountChoice>(
      context: context,
      builder: (dialogContext) {
        void choose(_AmbiguousAccountChoice choice) {
          Navigator.of(dialogContext).pop(choice);
        }

        return AlertDialog(
          title: Text(l10n.accountsAmbiguousConnectionDialogTitle),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(l10n.accountsAmbiguousConnectionDialogBody(count)),
                for (final account in ambiguous)
                  _AmbiguousAccountComparison(account: account),
                const SizedBox(height: AppSpacing.lg),
                Text(
                  anyMask
                      ? l10n.accountsAmbiguousConnectionDialogCheckDigitsQuestion(
                          count,
                        )
                      : l10n.accountsAmbiguousConnectionDialogQuestion(count),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => choose(_AmbiguousAccountChoice.alreadyConnected),
              child: Text(l10n.accountsAmbiguousConnectionDialogAlreadyConnected),
            ),
            TextButton(
              onPressed: () => choose(_AmbiguousAccountChoice.differentAccount),
              child: Text(l10n.accountsAmbiguousConnectionDialogConfirm),
            ),
          ],
        );
      },
    );
  }

  Future<void> _showDisconnectedExistingDialog(
    List<PlaidLinkAccountReview> accounts,
  ) async {
    final l10n = AppLocalizations.of(context);
    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(l10n.accountsDisconnectedExistingDialogTitle),
          content: _linkReviewContent(
            l10n,
            l10n.accountsDisconnectedExistingDialogBody,
            accounts,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: Text(l10n.accountsDisconnectedExistingDialogAction),
            ),
          ],
        );
      },
    );
  }

  Widget _linkReviewContent(
    AppLocalizations l10n,
    String body,
    List<PlaidLinkAccountReview> accounts,
  ) {
    return SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(body),
          if (accounts.isNotEmpty) const SizedBox(height: AppSpacing.sm),
          for (final account in accounts)
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.xs),
              child: Text(_linkReviewLine(l10n, account)),
            ),
        ],
      ),
    );
  }

  static String _linkReviewLine(
    AppLocalizations l10n,
    PlaidLinkAccountReview account,
  ) {
    final mask = account.mask;
    final label = mask == null
        ? account.name
        : '${account.name} \u2022\u2022\u2022\u2022$mask';
    return account.decision == PlaidLinkAccountDecision.disconnectedExisting
        ? '$label \u2014 ${l10n.accountsLinkAccountDisconnectedLabel}'
        : label;
  }

  Future<void> _syncConnectedAccounts(String connectionId) async {
    final syncAccounts = ref.read(plaidAccountsSyncCallbackProvider);
    final result = await syncAccounts(connectionId);

    if (!mounted) {
      return;
    }

    if (result is Failure<PlaidAccountsSyncSummary>) {
      final l10n = AppLocalizations.of(context);
      switch (result.failure) {
        case PlaidItemLoginRequiredFailure():
          setState(() => _syncLoginRequiredConnectionIds.add(connectionId));
          _showMessage(l10n.accountsReconnectRequiredTitle);
          await _refreshAfterMutation();
        case NotFoundFailure():
          _showMessage(l10n.accountsConnectionNotFound);
          await _refreshAfterMutation();
        case PlaidConnectionDisconnectedFailure():
          _showMessage(l10n.accountsDisconnectedBody);
          await _refreshAfterMutation();
        default:
          _showMessage(l10n.failureUnknown);
      }
      return;
    }

    await _refreshAfterMutation();
  }

  /// Returns whether the post-repair accounts sync still reports
  /// item_login_required.
  Future<bool> _syncAndRefreshAfterRepair(String connectionId) async {
    final result = await ref.read(plaidAccountsSyncCallbackProvider)(
      connectionId,
    );
    if (!mounted) {
      return false;
    }

    final stillLoginRequired =
        result is Failure<PlaidAccountsSyncSummary> &&
        result.failure is PlaidItemLoginRequiredFailure;
    if (stillLoginRequired) {
      setState(() => _syncLoginRequiredConnectionIds.add(connectionId));
    }

    await ref.read(accountsDataRefreshProvider).refresh();
    return stillLoginRequired;
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _syncBankConnection(String connectionId) async {
    if (_isConnectionBusy(connectionId) || _isDisconnected(connectionId)) {
      return;
    }

    setState(() => _syncingConnectionIds.add(connectionId));
    try {
      await _syncConnectedAccounts(connectionId);
    } finally {
      if (mounted) {
        setState(() => _syncingConnectionIds.remove(connectionId));
      }
    }
  }

  Future<void> _reconnectBankConnection(
    String connectionId, {
    bool isAccessExtension = false,
  }) async {
    if (_isConnectionBusy(connectionId) ||
        _isDisconnected(connectionId) ||
        _reconnectUnavailableConnectionIds.contains(connectionId)) {
      return;
    }

    setState(() => _reconnectingConnectionIds.add(connectionId));

    try {
      final locale = Localizations.localeOf(context).toLanguageTag();
      final outcome = await ref
          .read(plaidConnectServiceProvider)
          .reconnect(connectionId: connectionId, locale: locale);

      if (!mounted) {
        return;
      }

      final l10n = AppLocalizations.of(context);
      switch (outcome) {
        case PlaidReconnectCancelled():
          break;
        case PlaidReconnectConfirmed(:final refresh):
          if (refresh.status == PlaidConnectionStatus.active) {
            setState(() => _syncLoginRequiredConnectionIds.remove(connectionId));
            final stillLoginRequired = await _syncAndRefreshAfterRepair(
              connectionId,
            );
            if (!mounted) {
              return;
            }
            if (stillLoginRequired) {
              _showMessage(l10n.accountsReconnectRequiredTitle);
            } else {
              _showMessage(
                isAccessExtension
                    ? l10n.accountsAccessExtended
                    : l10n.accountsReconnectSuccess,
              );
            }
          } else {
            ref.invalidate(plaidConnectionHealthProvider);
            _showMessage(l10n.accountsReconnectStillRequired);
          }
        case PlaidReconnectFailed(:final failure):
          switch (failure) {
            case PlaidReconnectUnavailableFailure():
              setState(
                () => _reconnectUnavailableConnectionIds.add(connectionId),
              );
              _showMessage(l10n.accountsReconnectUnavailable);
            case NotFoundFailure():
              _showMessage(l10n.accountsConnectionNotFound);
              await _refreshAfterMutation();
            default:
              _showMessage(l10n.accountsReconnectFailed);
          }
      }
    } finally {
      if (mounted) {
        setState(() => _reconnectingConnectionIds.remove(connectionId));
      }
    }
  }

  Future<void> _disconnectBankConnection(String connectionId) async {
    if (_isConnectionBusy(connectionId) || _isDisconnected(connectionId)) {
      return;
    }

    final l10n = AppLocalizations.of(context);
    final confirmed = await _confirmConnectionAction(
      title: l10n.accountsDisconnectDialogTitle,
      body: l10n.accountsDisconnectDialogBody,
      confirmLabel: l10n.accountsDisconnectConfirm,
      isDestructive: false,
    );
    if (!confirmed || !mounted) {
      return;
    }

    await _runLifecycleAction(
      connectionId: connectionId,
      action: ref.read(plaidItemDisconnectCallbackProvider),
      successMessage: l10n.accountsDisconnected,
      errorMessage: l10n.accountsDisconnectError,
    );
  }

  Future<void> _deleteBankConnection(String connectionId) async {
    if (_isConnectionBusy(connectionId)) {
      return;
    }

    final l10n = AppLocalizations.of(context);
    final confirmed = await _confirmConnectionAction(
      title: l10n.accountsRemoveBankConnectionDialogTitle,
      body: l10n.accountsRemoveBankConnectionDialogBody,
      confirmLabel: l10n.accountsDeleteConfirm,
      isDestructive: true,
    );
    if (!confirmed || !mounted) {
      return;
    }

    await _runLifecycleAction(
      connectionId: connectionId,
      action: ref.read(plaidItemDeleteCallbackProvider),
      successMessage: l10n.accountsConnectionDeleted,
      errorMessage: l10n.accountsRemoveBankConnectionError,
      onSuccess: () {
        _expandedBankGroupKeys.remove(connectionId);
        _syncLoginRequiredConnectionIds.remove(connectionId);
        _reconnectUnavailableConnectionIds.remove(connectionId);
      },
    );
  }

  /// Every outcome ends with a post-mutation re-read: an unknown or partial
  /// server outcome is resolved by the database, never by guessing locally.
  Future<void> _runLifecycleAction({
    required String connectionId,
    required PlaidItemLifecycleCallback action,
    required String successMessage,
    required String errorMessage,
    VoidCallback? onSuccess,
  }) async {
    // The confirmation dialog awaited; another action may have started.
    if (_isConnectionBusy(connectionId)) {
      return;
    }

    setState(() => _lifecycleConnectionIds.add(connectionId));

    try {
      final result = await action(connectionId);
      if (!mounted) {
        return;
      }

      if (result is Success<void>) {
        onSuccess?.call();
      }

      await _refreshAfterMutation();
      if (!mounted) {
        return;
      }

      final l10n = AppLocalizations.of(context);
      _showMessage(switch (result) {
        Success<void>() => successMessage,
        Failure<void>(failure: NotFoundFailure()) =>
          l10n.accountsConnectionNotFound,
        Failure<void>() => errorMessage,
      });
    } finally {
      if (mounted) {
        setState(() => _lifecycleConnectionIds.remove(connectionId));
      }
    }
  }

  Future<bool> _confirmConnectionAction({
    required String title,
    required String body,
    required String confirmLabel,
    required bool isDestructive,
  }) async {
    final l10n = AppLocalizations.of(context);
    final colors = context.appThemeColors;
    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(title),
          content: Text(body),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: Text(l10n.commonCancel),
            ),
            TextButton(
              style: isDestructive
                  ? TextButton.styleFrom(foregroundColor: colors.error)
                  : null,
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: Text(confirmLabel),
            ),
          ],
        );
      },
    );

    return result ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final accountsState = ref.watch(accountControllerProvider);
    final institutionsState = ref.watch(accountInstitutionsProvider);
    final institutionsById = _institutionsById(institutionsState);
    final healthByConnectionId = _healthByConnectionId(
      ref.watch(plaidConnectionHealthProvider),
    );
    final l10n = AppLocalizations.of(context);
    const adapter = AccountAdapter();

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Padding(
          padding: AppSpacing.screen,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: accountsState.when(
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (error, stackTrace) => Center(
                    child: Text(
                      l10n.failureUnknown,
                      style: AppTypography.bodyMd.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                  data: (result) {
                    return switch (result) {
                      Success<List<Account>>(:final value) =>
                        _buildAccountsList(
                          l10n: l10n,
                          accounts: value,
                          institutionsById: institutionsById,
                          healthByConnectionId: healthByConnectionId,
                          adapter: adapter,
                        ),
                      Failure<List<Account>>() => const AccountsEmptyState(),
                    };
                  },
                ),
              ),
              FilledButton(
                onPressed: _isConnecting ? null : _connectBank,
                child: _isConnecting
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(
                        l10n.accountsConnectBank,
                        style: AppTypography.buttonMd,
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAccountsList({
    required AppLocalizations l10n,
    required List<Account> accounts,
    required Map<String, Institution> institutionsById,
    required Map<String, PlaidConnectionHealth> healthByConnectionId,
    required AccountAdapter adapter,
  }) {
    final groups = _groupAccountsByBank(accounts);
    final noticesByConnectionId = {
      for (final group in groups)
        group.connectionId: _healthNotice(
          group.connectionId,
          healthByConnectionId[group.connectionId],
        ),
    };

    final children = <Widget>[
      Text(
        l10n.accountsTitle,
        style: AppTypography.headingLg.copyWith(color: AppColors.textPrimary),
      ),
      if (groups.isEmpty)
        const AccountsEmptyState()
      else
        for (final group in groups)
          _BankAccountGroupView(
            group: group,
            institution: institutionsById[group.institutionId],
            isExpanded: _expandedBankGroupKeys.contains(group.key),
            accountAdapter: adapter,
            l10n: l10n,
            isBusy:
                _syncingConnectionIds.contains(group.connectionId) ||
                _lifecycleConnectionIds.contains(group.connectionId),
            isDisconnected:
                healthByConnectionId[group.connectionId]?.isDisconnected ??
                false,
            healthNotice: noticesByConnectionId[group.connectionId],
            isReconnecting: _reconnectingConnectionIds.contains(
              group.connectionId,
            ),
            onToggleExpanded: () => _toggleBankGroup(group.key),
            onSync: () => _syncBankConnection(group.connectionId),
            onDisconnect: () => _disconnectBankConnection(group.connectionId),
            onDelete: () => _deleteBankConnection(group.connectionId),
            onReconnect: () => _reconnectBankConnection(
              group.connectionId,
              isAccessExtension:
                  noticesByConnectionId[group.connectionId]
                      is _AccessExtensionNotice,
            ),
            onFinancialParticipationChanged: _setFinancialParticipation,
          ),
    ];

    return ListView.separated(
      itemCount: children.length,
      separatorBuilder: (context, index) {
        return const SizedBox(height: AppSpacing.hairline);
      },
      itemBuilder: (context, index) => children[index],
    );
  }

  Map<String, Institution> _institutionsById(
    AsyncValue<Result<List<Institution>>> state,
  ) {
    return state.when(
      data: (result) {
        if (result is! Success<List<Institution>>) {
          return const {};
        }

        return {
          for (final institution in result.value) institution.id: institution,
        };
      },
      error: (error, stackTrace) => const {},
      loading: () => const {},
    );
  }

  Map<String, PlaidConnectionHealth> _healthByConnectionId(
    AsyncValue<Result<List<PlaidConnectionHealth>>> state,
  ) {
    return state.when(
      data: (result) {
        if (result is! Success<List<PlaidConnectionHealth>>) {
          return const {};
        }

        return {
          for (final health in result.value) health.connectionId: health,
        };
      },
      error: (error, stackTrace) => const {},
      loading: () => const {},
    );
  }

  _HealthNotice? _healthNotice(
    String connectionId,
    PlaidConnectionHealth? health,
  ) {
    // The database is the only source of the disconnected state; it hides
    // every repair or extension notice of an Item that no longer exists.
    if (health?.isDisconnected ?? false) {
      return const _DisconnectedNotice();
    }

    if (_reconnectUnavailableConnectionIds.contains(connectionId)) {
      return const _ReconnectUnavailableNotice();
    }

    if (_syncLoginRequiredConnectionIds.contains(connectionId) ||
        (health?.requiresReconnect ?? false)) {
      return const _ReconnectRequiredNotice();
    }

    if (health?.requiresAccessExtension ?? false) {
      return const _AccessExtensionNotice();
    }

    return null;
  }

  List<_BankAccountGroup> _groupAccountsByBank(List<Account> accounts) {
    final groups = <String, _BankAccountGroup>{};

    for (final account in accounts) {
      final connectionId = _normalizedPlaidItemId(account);
      final institutionId = _normalizedInstitutionId(account);
      if (connectionId == null || institutionId == null) {
        continue;
      }

      groups
          .putIfAbsent(
            connectionId,
            () => _BankAccountGroup(
              key: connectionId,
              connectionId: connectionId,
              institutionId: institutionId,
              accounts: <Account>[],
            ),
          )
          .accounts
          .add(account);
    }

    return groups.values.toList(growable: false);
  }

  void _toggleBankGroup(String key) {
    setState(() {
      if (!_expandedBankGroupKeys.add(key)) {
        _expandedBankGroupKeys.remove(key);
      }
    });
  }

  Future<void> _setFinancialParticipation(
    Account account,
    bool isIncludedInFinances,
  ) async {
    if (!isIncludedInFinances) {
      final confirmed = await _confirmFinancialExclusion();
      if (!confirmed || !mounted) {
        return;
      }
    }

    final result = await ref
        .read(accountControllerProvider.notifier)
        .setFinancialParticipation(
          accountId: account.id,
          isIncludedInFinances: isIncludedInFinances,
        );

    if (!mounted) {
      return;
    }

    if (result is Failure<Account>) {
      final l10n = AppLocalizations.of(context);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(result.failure.localized(l10n))));
    }
  }

  Future<bool> _confirmFinancialExclusion() async {
    final l10n = AppLocalizations.of(context);
    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(l10n.accountsFinancialExclusionDialogTitle),
          content: Text(l10n.accountsFinancialExclusionDialogBody),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: Text(l10n.accountsFinancialExclusionDialogCancel),
            ),
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: Text(l10n.accountsFinancialExclusionDialogConfirm),
            ),
          ],
        );
      },
    );

    return result ?? false;
  }

  String? _normalizedPlaidItemId(Account account) {
    final plaidItemId = account.plaidItemId?.trim();
    if (plaidItemId == null || plaidItemId.isEmpty) {
      return null;
    }
    return plaidItemId;
  }

  String? _normalizedInstitutionId(Account account) {
    final institutionId = account.institutionId?.trim();
    if (institutionId == null || institutionId.isEmpty) {
      return null;
    }
    return institutionId;
  }

  static String? _accountSubtitle(Account account) {
    return _identityDetails(
      account.plaidSubtype?.trim() ?? account.plaidType?.trim(),
      account.mask?.trim(),
    );
  }

  static String? _identityDetails(String? type, String? mask) {
    final parts = <String>[];
    if (type != null && type.isNotEmpty) {
      parts.add(type);
    }

    if (mask != null && mask.isNotEmpty) {
      parts.add('\u2022\u2022\u2022\u2022$mask');
    }

    if (parts.isEmpty) {
      return null;
    }

    return parts.join(' \u2022 ');
  }

  static double? _displayBalance(Account account) {
    return account.currentBalance;
  }

  static String? _displayCurrency(Account account) {
    return account.currencyCode ?? account.unofficialCurrencyCode;
  }
}

enum _BankMenuAction { sync, disconnect, delete }

enum _AmbiguousAccountChoice { alreadyConnected, differentAccount }

/// The account selected in Link next to the similar accounts already in
/// Ophir. Lines wrap instead of truncating so the last digits stay visible.
class _AmbiguousAccountComparison extends StatelessWidget {
  const _AmbiguousAccountComparison({required this.account});

  static const _maxShownSimilarAccounts = 3;

  final PlaidLinkAccountReview account;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final labelStyle = AppTypography.bodySm.copyWith(
      color: context.appThemeColors.textSecondary,
    );
    final similar = account.similarAccounts;
    final shown = similar.take(_maxShownSimilarAccounts).toList();
    final hidden = similar.length - shown.length;

    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.lg),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.accountsAmbiguousConnectionDialogConnectingLabel,
            style: labelStyle,
          ),
          Text(_AccountsScreenState._linkReviewLine(l10n, account)),
          if (shown.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              l10n.accountsAmbiguousConnectionDialogExistingLabel,
              style: labelStyle,
            ),
            for (final candidate in shown)
              _SimilarAccountLines(candidate: candidate, detailStyle: labelStyle),
            if (hidden > 0)
              Padding(
                padding: const EdgeInsets.only(top: AppSpacing.xs),
                child: Text(
                  l10n.accountsAmbiguousConnectionDialogMoreCandidates(hidden),
                  style: labelStyle,
                ),
              ),
          ],
        ],
      ),
    );
  }
}

class _SimilarAccountLines extends StatelessWidget {
  const _SimilarAccountLines({
    required this.candidate,
    required this.detailStyle,
  });

  final PlaidSimilarAccount candidate;
  final TextStyle detailStyle;

  @override
  Widget build(BuildContext context) {
    final details = _AccountsScreenState._identityDetails(
      candidate.subtype,
      candidate.mask,
    );
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.xs),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(candidate.name),
          if (details != null) Text(details, style: detailStyle),
        ],
      ),
    );
  }
}

final class _BankAccountGroup {
  const _BankAccountGroup({
    required this.key,
    required this.connectionId,
    required this.institutionId,
    required this.accounts,
  });

  final String key;
  final String connectionId;
  final String institutionId;
  final List<Account> accounts;
}

class _BankAccountGroupView extends StatelessWidget {
  const _BankAccountGroupView({
    required this.group,
    required this.institution,
    required this.isExpanded,
    required this.accountAdapter,
    required this.l10n,
    required this.isBusy,
    required this.isDisconnected,
    required this.healthNotice,
    required this.isReconnecting,
    required this.onToggleExpanded,
    required this.onSync,
    required this.onDisconnect,
    required this.onDelete,
    required this.onReconnect,
    required this.onFinancialParticipationChanged,
  });

  final _BankAccountGroup group;
  final Institution? institution;
  final bool isExpanded;
  final AccountAdapter accountAdapter;
  final AppLocalizations l10n;
  final bool isBusy;
  final bool isDisconnected;
  final _HealthNotice? healthNotice;
  final bool isReconnecting;
  final VoidCallback onToggleExpanded;
  final Future<void> Function() onSync;
  final Future<void> Function() onDisconnect;
  final Future<void> Function() onDelete;
  final Future<void> Function() onReconnect;
  final Future<void> Function(Account account, bool isIncludedInFinances)
  onFinancialParticipationChanged;

  @override
  Widget build(BuildContext context) {
    final notice = healthNotice;
    final children = <Widget>[
      _BankGroupHeader(
        group: group,
        institution: institution,
        isExpanded: isExpanded,
        l10n: l10n,
        isBusy: isBusy,
        isDisconnected: isDisconnected,
        onToggleExpanded: onToggleExpanded,
        onSync: onSync,
        onDisconnect: onDisconnect,
        onDelete: onDelete,
      ),
      if (notice != null)
        _ConnectionHealthBanner(
          key: ValueKey('connection-health-${group.connectionId}'),
          notice: notice,
          l10n: l10n,
          isReconnecting: isReconnecting,
          onReconnect: onReconnect,
        ),
    ];

    if (isExpanded) {
      children.addAll([
        const SizedBox(height: AppSpacing.xs),
        for (final account in group.accounts)
          _FinancialParticipationAccountRow(
            account: account,
            accountAdapter: accountAdapter,
            l10n: l10n,
            onChanged: onFinancialParticipationChanged,
          ),
      ]);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: children,
    );
  }
}

sealed class _HealthNotice {
  const _HealthNotice();
}

final class _ReconnectRequiredNotice extends _HealthNotice {
  const _ReconnectRequiredNotice();
}

final class _ReconnectUnavailableNotice extends _HealthNotice {
  const _ReconnectUnavailableNotice();
}

final class _AccessExtensionNotice extends _HealthNotice {
  const _AccessExtensionNotice();
}

final class _DisconnectedNotice extends _HealthNotice {
  const _DisconnectedNotice();
}

class _ConnectionHealthBanner extends StatelessWidget {
  const _ConnectionHealthBanner({
    super.key,
    required this.notice,
    required this.l10n,
    required this.isReconnecting,
    required this.onReconnect,
  });

  final _HealthNotice notice;
  final AppLocalizations l10n;
  final bool isReconnecting;
  final Future<void> Function() onReconnect;

  @override
  Widget build(BuildContext context) {
    final colors = context.appThemeColors;
    final (accent, title, body) = switch (notice) {
      _ReconnectRequiredNotice() => (
        colors.error,
        l10n.accountsReconnectRequiredTitle,
        l10n.accountsReconnectRequiredBody,
      ),
      _ReconnectUnavailableNotice() => (
        colors.error,
        l10n.accountsReconnectRequiredTitle,
        l10n.accountsReconnectUnavailable,
      ),
      _AccessExtensionNotice() => (
        colors.warning,
        null,
        l10n.accountsAccessExtensionRequired,
      ),
      _DisconnectedNotice() => (
        colors.textSecondary,
        l10n.accountsDisconnectedTitle,
        l10n.accountsDisconnectedBody,
      ),
    };
    final action = switch (notice) {
      _ReconnectRequiredNotice() => (
        l10n.accountsReconnectAction,
        l10n.accountsReconnecting,
      ),
      _AccessExtensionNotice() => (
        l10n.accountsExtendAccessAction,
        l10n.accountsExtendingAccess,
      ),
      _ReconnectUnavailableNotice() || _DisconnectedNotice() => null,
    };

    return Container(
      margin: const EdgeInsets.only(top: AppSpacing.sm),
      padding: AppSpacing.compactCardInsets,
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border.all(color: accent),
        borderRadius: AppRadius.smRadius,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (title != null)
            Text(
              title,
              style: AppTypography.bodyStrong.copyWith(color: accent),
            ),
          Text(
            body,
            style: AppTypography.bodySm.copyWith(color: colors.textSecondary),
          ),
          if (action case (final label, final busyLabel))
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: isReconnecting ? null : onReconnect,
                child: Text(isReconnecting ? busyLabel : label),
              ),
            ),
        ],
      ),
    );
  }
}

class _BankGroupHeader extends StatelessWidget {
  const _BankGroupHeader({
    required this.group,
    required this.institution,
    required this.isExpanded,
    required this.l10n,
    required this.isBusy,
    required this.isDisconnected,
    required this.onToggleExpanded,
    required this.onSync,
    required this.onDisconnect,
    required this.onDelete,
  });

  final _BankAccountGroup group;
  final Institution? institution;
  final bool isExpanded;
  final AppLocalizations l10n;
  final bool isBusy;
  final bool isDisconnected;
  final VoidCallback onToggleExpanded;
  final Future<void> Function() onSync;
  final Future<void> Function() onDisconnect;
  final Future<void> Function() onDelete;

  @override
  Widget build(BuildContext context) {
    final colors = context.appThemeColors;
    final name = institution?.name?.trim();
    final aggregateBalance = _aggregateBalance(group.accounts);

    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _InstitutionLogo(logoBase64: institution?.logoBase64),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: InkWell(
                        onTap: onToggleExpanded,
                        borderRadius: AppRadius.smRadius,
                        child: name == null || name.isEmpty
                            ? const SizedBox.shrink()
                            : Text(
                                name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: AppTypography.bodyStrong.copyWith(
                                  color: colors.textPrimary,
                                ),
                              ),
                      ),
                    ),
                    SizedBox(
                      width: AppDimensions.buttonMdHeight,
                      height: AppDimensions.buttonMdHeight,
                      child: isBusy
                          ? const Center(
                              child: SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              ),
                            )
                          : PopupMenuButton<_BankMenuAction>(
                              padding: EdgeInsets.zero,
                              icon: const Icon(Icons.more_vert),
                              onSelected: (action) async {
                                switch (action) {
                                  case _BankMenuAction.sync:
                                    await onSync();
                                  case _BankMenuAction.disconnect:
                                    await onDisconnect();
                                  case _BankMenuAction.delete:
                                    await onDelete();
                                }
                              },
                              itemBuilder: (context) {
                                // A disconnected Item has no Plaid link left
                                // to refresh or disconnect; only Delete remains.
                                return [
                                  if (!isDisconnected) ...[
                                    PopupMenuItem(
                                      value: _BankMenuAction.sync,
                                      child: Text(l10n.accountsBankMenuSync),
                                    ),
                                    PopupMenuItem(
                                      value: _BankMenuAction.disconnect,
                                      child: Text(
                                        l10n.accountsBankMenuDisconnect,
                                      ),
                                    ),
                                  ],
                                  PopupMenuItem(
                                    value: _BankMenuAction.delete,
                                    child: Text(
                                      l10n.accountsBankMenuRemoveConnection,
                                      style: AppTypography.bodyMd.copyWith(
                                        color: colors.error,
                                      ),
                                    ),
                                  ),
                                ];
                              },
                            ),
                    ),
                  ],
                ),
                if (aggregateBalance != null)
                  Padding(
                    padding: const EdgeInsets.only(top: AppSpacing.hairline),
                    child: InkWell(
                      onTap: onToggleExpanded,
                      borderRadius: AppRadius.smRadius,
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          aggregateBalance,
                          maxLines: 1,
                          softWrap: false,
                          overflow: TextOverflow.visible,
                          style: AppTypography.bodyMd.copyWith(
                            color: colors.textPrimary,
                          ),
                        ),
                      ),
                    ),
                  ),
                Row(
                  children: [
                    Expanded(
                      child: InkWell(
                        onTap: onToggleExpanded,
                        borderRadius: AppRadius.smRadius,
                        child: Text(
                          l10n.accountsInstitutionAccountCount(
                            group.accounts.length,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTypography.bodySm.copyWith(
                            color: colors.textSecondary,
                          ),
                        ),
                      ),
                    ),
                    SizedBox(
                      width: AppDimensions.buttonMdHeight,
                      height: AppDimensions.buttonMdHeight,
                      child: IconButton(
                        onPressed: onToggleExpanded,
                        icon: Icon(
                          isExpanded
                              ? Icons.keyboard_arrow_up
                              : Icons.keyboard_arrow_down,
                          color: colors.iconSecondary,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String? _aggregateBalance(List<Account> accounts) {
    if (accounts.isEmpty) {
      return null;
    }

    final currency = _AccountsScreenState._displayCurrency(accounts.first);
    if (currency == null) {
      return null;
    }

    var total = 0.0;
    for (final account in accounts) {
      final balance = _AccountsScreenState._displayBalance(account);
      if (balance == null ||
          _AccountsScreenState._displayCurrency(account) != currency) {
        return null;
      }

      total += balance;
    }

    return '${total.toStringAsFixed(2)} $currency';
  }
}

class _FinancialParticipationAccountRow extends StatelessWidget {
  const _FinancialParticipationAccountRow({
    required this.account,
    required this.accountAdapter,
    required this.l10n,
    required this.onChanged,
  });

  final Account account;
  final AccountAdapter accountAdapter;
  final AppLocalizations l10n;
  final Future<void> Function(Account account, bool isIncludedInFinances)
  onChanged;

  @override
  Widget build(BuildContext context) {
    final colors = context.appThemeColors;
    final statusLabel = account.isIncludedInFinances
        ? l10n.accountsFinancialParticipationIncludedStatus
        : l10n.accountsFinancialParticipationExcludedStatus;

    return Row(
      children: [
        Expanded(
          child: AccountListTile(
            account: accountAdapter.toPresentation(account),
            subtitle: _AccountsScreenState._accountSubtitle(account),
            balance: _AccountsScreenState._displayBalance(account),
            currencyCode: _AccountsScreenState._displayCurrency(account),
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              statusLabel,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.end,
              style: AppTypography.bodySm.copyWith(color: colors.textSecondary),
            ),
            AppCompactSwitch(
              value: account.isIncludedInFinances,
              onChanged: (value) => onChanged(account, value),
              semanticLabel: statusLabel,
            ),
          ],
        ),
      ],
    );
  }
}

class _InstitutionLogo extends StatelessWidget {
  const _InstitutionLogo({required this.logoBase64});

  final String? logoBase64;

  @override
  Widget build(BuildContext context) {
    final colors = context.appThemeColors;
    final logoBytes = _decodeLogo(logoBase64);

    return Container(
      width: AppDimensions.avatarMd,
      height: AppDimensions.avatarMd,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border.all(color: colors.border),
        borderRadius: AppRadius.smRadius,
      ),
      child: logoBytes == null
          ? null
          : ClipRRect(
              borderRadius: AppRadius.smRadius,
              child: Image.memory(
                logoBytes,
                width: AppDimensions.avatarMd,
                height: AppDimensions.avatarMd,
                fit: BoxFit.contain,
                errorBuilder: (context, error, stackTrace) {
                  return const SizedBox.shrink();
                },
              ),
            ),
    );
  }

  Uint8List? _decodeLogo(String? value) {
    final logo = value?.trim();
    if (logo == null || logo.isEmpty) {
      return null;
    }

    final payload = logo.contains(',') ? logo.split(',').last : logo;

    try {
      return base64Decode(payload);
    } catch (_) {
      return null;
    }
  }
}
