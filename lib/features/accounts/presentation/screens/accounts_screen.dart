import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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
import '../../data/plaid/plaid_accounts_sync_service.dart';
import '../../data/plaid/plaid_connect_service.dart';
import '../../domain/entities/account.dart';
import '../../domain/entities/institution.dart';
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

  Future<void> _connectBank() async {
    if (_isConnecting) {
      return;
    }

    setState(() => _isConnecting = true);

    try {
      final locale = Localizations.localeOf(context).toLanguageTag();
      final outcome = await PlaidConnectService(
        Supabase.instance.client,
      ).connect(locale: locale);

      if (!mounted) {
        return;
      }

      switch (outcome) {
        case PlaidConnectCompleted(:final connectionId):
          await _syncConnectedAccounts(connectionId);
        case PlaidConnectDuplicate():
          await _showDuplicateConnectionDialog();
        case PlaidConnectCancelled():
          break;
        case PlaidConnectFailed(:final failure):
          final l10n = AppLocalizations.of(context);
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(failure.localized(l10n))));
      }
    } finally {
      if (mounted) {
        setState(() => _isConnecting = false);
      }
    }
  }

  Future<void> _showDuplicateConnectionDialog() async {
    if (!mounted) {
      return;
    }

    final l10n = AppLocalizations.of(context);
    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(l10n.accountsDuplicateConnectionDialogTitle),
          content: Text(l10n.accountsDuplicateConnectionDialogBody),
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

  Future<void> _syncConnectedAccounts(String connectionId) async {
    final syncAccounts = ref.read(plaidAccountsSyncCallbackProvider);
    final result = await syncAccounts(connectionId);

    if (!mounted) {
      return;
    }

    if (result is Failure<PlaidAccountsSyncSummary>) {
      final l10n = AppLocalizations.of(context);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.failureUnknown)));
      return;
    }

    ref.invalidate(accountInstitutionsProvider);
    await ref.read(accountControllerProvider.notifier).refresh();
  }

  @override
  Widget build(BuildContext context) {
    final accountsState = ref.watch(accountControllerProvider);
    final institutionsState = ref.watch(accountInstitutionsProvider);
    final institutionsById = _institutionsById(institutionsState);
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
    required AccountAdapter adapter,
  }) {
    final groups = _groupAccountsByBank(accounts);

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
            onToggleExpanded: () => _toggleBankGroup(group.key),
            onSync: () => _syncConnectedAccounts(group.connectionId),
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
    final parts = <String>[];
    final type = account.plaidSubtype?.trim() ?? account.plaidType?.trim();
    if (type != null && type.isNotEmpty) {
      parts.add(type);
    }

    final mask = account.mask?.trim();
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

enum _BankMenuAction { sync }

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
    required this.onToggleExpanded,
    required this.onSync,
    required this.onFinancialParticipationChanged,
  });

  final _BankAccountGroup group;
  final Institution? institution;
  final bool isExpanded;
  final AccountAdapter accountAdapter;
  final AppLocalizations l10n;
  final VoidCallback onToggleExpanded;
  final Future<void> Function() onSync;
  final Future<void> Function(Account account, bool isIncludedInFinances)
  onFinancialParticipationChanged;

  @override
  Widget build(BuildContext context) {
    final children = <Widget>[
      _BankGroupHeader(
        group: group,
        institution: institution,
        isExpanded: isExpanded,
        l10n: l10n,
        onToggleExpanded: onToggleExpanded,
        onSync: onSync,
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

class _BankGroupHeader extends StatelessWidget {
  const _BankGroupHeader({
    required this.group,
    required this.institution,
    required this.isExpanded,
    required this.l10n,
    required this.onToggleExpanded,
    required this.onSync,
  });

  final _BankAccountGroup group;
  final Institution? institution;
  final bool isExpanded;
  final AppLocalizations l10n;
  final VoidCallback onToggleExpanded;
  final Future<void> Function() onSync;

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
                      child: PopupMenuButton<_BankMenuAction>(
                        padding: EdgeInsets.zero,
                        icon: const Icon(Icons.more_vert),
                        onSelected: (action) async {
                          switch (action) {
                            case _BankMenuAction.sync:
                              await onSync();
                          }
                        },
                        itemBuilder: (context) {
                          return [
                            PopupMenuItem(
                              value: _BankMenuAction.sync,
                              child: Text(l10n.accountsBankMenuSync),
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
