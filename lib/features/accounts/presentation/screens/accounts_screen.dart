import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/app_routes.dart';
import '../../../../core/errors/result.dart';
import '../../../../core/icons/app_icons.dart';
import '../../../../core/localization/generated/app_localizations.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../controller/account_controller.dart';
import '../../domain/entities/account.dart';
import '../adapters/account_adapter.dart';
import '../widgets/account_list_tile.dart';
import '../widgets/accounts_empty_state.dart';

class AccountsScreen extends ConsumerWidget {
  const AccountsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final accountsState = ref.watch(accountControllerProvider);
    final l10n = AppLocalizations.of(context);
    const adapter = AccountAdapter();

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Padding(
          padding: AppSpacing.screen,
          child: accountsState.when(
            loading: () => const Center(child: CircularProgressIndicator()),
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
                Success<List<Account>>(:final value) => value.isEmpty
                    ? const AccountsEmptyState()
                    : ListView.separated(
                  itemCount: value.length + 1,
                  separatorBuilder: (context, index) {
                    return const SizedBox(height: AppSpacing.sm);
                  },
                  itemBuilder: (context, index) {
                    if (index == 0) {
                      return Text(
                        l10n.accountsTitle,
                        style: AppTypography.headingLg.copyWith(
                          color: AppColors.textPrimary,
                        ),
                      );
                    }

                    final account = value[index - 1];
                    final presentation = adapter.toPresentation(account);

                    return AccountListTile(
                      account: presentation,
                      initialBalance: account.initialBalance,
                      currencyCode: account.currencyCode,
                    );
                  },
                ),
                Failure<List<Account>>() => const AccountsEmptyState(),
              };
            },
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.textInverse,
        onPressed: () => context.push(AppRoutes.createAccount),
        child: const Icon(AppIcons.actionAdd),
      ),
    );
  }
}