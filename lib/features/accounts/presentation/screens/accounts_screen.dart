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

  Future<void> _syncConnectedAccounts(String connectionId) async {
    final result = await PlaidAccountsSyncService(
      Supabase.instance.client,
    ).syncAccounts(connectionId);

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
    final groupedAccounts = _groupAccountsByInstitution(accounts);

    final children = <Widget>[
      Text(
        l10n.accountsTitle,
        style: AppTypography.headingLg.copyWith(color: AppColors.textPrimary),
      ),
      if (groupedAccounts.isEmpty)
        const AccountsEmptyState()
      else
        for (final entry in groupedAccounts.entries) ...[
          _InstitutionHeader(institution: institutionsById[entry.key]),
          for (final account in entry.value)
            AccountListTile(
              account: adapter.toPresentation(account),
              subtitle: _maskedAccountNumber(account),
              balance: _displayBalance(account),
              currencyCode: _displayCurrency(account),
            ),
        ],
    ];

    return ListView.separated(
      itemCount: children.length,
      separatorBuilder: (context, index) {
        return const SizedBox(height: AppSpacing.sm);
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

  Map<String, List<Account>> _groupAccountsByInstitution(
    List<Account> accounts,
  ) {
    final groups = <String, List<Account>>{};

    for (final account in accounts) {
      final institutionId = _normalizedInstitutionId(account);
      if (institutionId == null) {
        continue;
      }

      groups.putIfAbsent(institutionId, () => <Account>[]).add(account);
    }

    return groups;
  }

  String? _normalizedInstitutionId(Account account) {
    final institutionId = account.institutionId?.trim();
    if (institutionId == null || institutionId.isEmpty) {
      return null;
    }
    return institutionId;
  }

  String? _maskedAccountNumber(Account account) {
    final mask = account.mask?.trim();
    if (mask == null || mask.isEmpty) {
      return null;
    }
    return '\u2022\u2022\u2022\u2022$mask';
  }

  double? _displayBalance(Account account) {
    return account.currentBalance;
  }

  String? _displayCurrency(Account account) {
    return account.currencyCode ?? account.unofficialCurrencyCode;
  }
}

class _InstitutionHeader extends StatelessWidget {
  const _InstitutionHeader({required this.institution});

  final Institution? institution;

  @override
  Widget build(BuildContext context) {
    final colors = context.appThemeColors;
    final name = institution?.name?.trim();

    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.md),
      child: Row(
        children: [
          _InstitutionLogo(logoBase64: institution?.logoBase64),
          if (name != null && name.isNotEmpty) ...[
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(
                name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.bodyStrong.copyWith(
                  color: colors.textPrimary,
                ),
              ),
            ),
          ],
        ],
      ),
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
