import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/errors/app_failure_localization.dart';
import '../../../../core/errors/result.dart';
import '../../../../core/localization/generated/app_localizations.dart';
import '../../../../core/theme_v1/app_colors.dart';
import '../../../../core/theme_v1/app_spacing.dart';
import '../../../../core/theme_v1/app_typography.dart';
import '../../controller/account_controller.dart';
import '../../data/plaid/plaid_connect_service.dart';
import '../../domain/entities/account.dart';
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

    final locale = Localizations.localeOf(context).toLanguageTag();
    final outcome = await PlaidConnectService(
      Supabase.instance.client,
    ).connect(locale: locale);

    if (!mounted) {
      return;
    }

    setState(() => _isConnecting = false);

    if (outcome case PlaidConnectFailed(:final failure)) {
      final l10n = AppLocalizations.of(context);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(failure.localized(l10n))));
    }
  }

  @override
  Widget build(BuildContext context) {
    final accountsState = ref.watch(accountControllerProvider);
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
    required AccountAdapter adapter,
  }) {
    final children = <Widget>[
      Text(
        l10n.accountsTitle,
        style: AppTypography.headingLg.copyWith(color: AppColors.textPrimary),
      ),
      if (accounts.isEmpty)
        const AccountsEmptyState()
      else
        for (final account in accounts)
          AccountListTile(
            account: adapter.toPresentation(account),
            initialBalance: account.initialBalance,
            currencyCode: account.currencyCode,
          ),
    ];

    return ListView.separated(
      itemCount: children.length,
      separatorBuilder: (context, index) {
        return const SizedBox(height: AppSpacing.sm);
      },
      itemBuilder: (context, index) => children[index],
    );
  }
}
