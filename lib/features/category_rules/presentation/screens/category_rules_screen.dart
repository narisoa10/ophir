import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/categories/app_categories.dart';
import '../../../../core/localization/generated/app_localizations.dart';
import '../../../../core/theme_v1/app_theme_colors.dart';
import '../../../../core/theme_v1/app_spacing.dart';
import '../../../../core/theme_v1/app_typography.dart';
import '../../controller/category_rule_controller.dart';
import '../../controller/category_rule_providers.dart';

/// Stage 3 — list and delete saved merchant category rules.
class CategoryRulesScreen extends ConsumerWidget {
  const CategoryRulesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final rulesState = ref.watch(categoryRulesProvider);

    return Scaffold(
      backgroundColor: context.appThemeColors.background,
      appBar: AppBar(
        title: Text(l10n.categoryRulesTitle),
        backgroundColor: context.appThemeColors.background,
        foregroundColor: context.appThemeColors.textPrimary,
        elevation: 0,
      ),
      body: rulesState.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, stackTrace) => Center(child: Text(l10n.failureUnknown)),
        data: (rules) {
          if (rules.isEmpty) {
            return Center(
              child: Padding(
                padding: AppSpacing.screen,
                child: Text(
                  l10n.categoryRulesEmpty,
                  style: AppTypography.body.copyWith(
                    color: context.appThemeColors.textSecondary,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }

          return ListView.separated(
            padding: AppSpacing.screen,
            itemCount: rules.length,
            separatorBuilder: (context, index) =>
                const SizedBox(height: AppSpacing.sm),
            itemBuilder: (context, index) {
              final rule = rules[index];
              final category = AppCategories.byIdName(rule.categoryId);

              return ListTile(
                tileColor: context.appThemeColors.surface,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                title: Text(rule.merchantKey, style: AppTypography.bodyStrong),
                subtitle: Text(
                  category?.name(l10n) ?? rule.categoryId,
                  style: AppTypography.caption,
                ),
                trailing: IconButton(
                  icon: const Icon(Icons.delete_outline),
                  onPressed: () async {
                    await ref
                        .read(categoryRuleControllerProvider.notifier)
                        .deleteRule(rule.id);
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }
}
