import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/app_routes.dart';
import '../../../../core/localization/generated/app_localizations.dart';
import '../../../../core/theme_v1/app_theme_colors.dart';
import '../../../../core/theme_v1/app_radius.dart';
import '../../../../core/theme_v1/app_spacing.dart';
import '../../../../core/theme_v1/app_typography.dart';
import '../../../category_rules/controller/category_rule_providers.dart';
import '../../../operations/domain/entities/operation.dart';
import '../../../operations/domain/utils/operation_needs_categorization.dart';

/// Stage 4 — dashboard prompt to review uncategorized bank-sync operations.
class DashboardCategorizationAction extends ConsumerWidget {
  const DashboardCategorizationAction({required this.operations, super.key});

  final List<Operation> operations;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final count = countOperationsNeedingCategorization(operations);
    if (count == 0) {
      return const SizedBox.shrink();
    }

    final l10n = AppLocalizations.of(context);
    final colors = context.appThemeColors;

    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.lg),
      child: Material(
        color: colors.surface,
        borderRadius: AppRadius.cardRadius,
        child: InkWell(
          borderRadius: AppRadius.cardRadius,
          onTap: () {
            ref.read(operationReviewFilterEnabledProvider.notifier).enabled =
                true;
            context.go(AppRoutes.operations);
          },
          child: Padding(
            padding: AppSpacing.cardInsets,
            child: Row(
              children: [
                Icon(Icons.label_outline, color: colors.primary),
                const SizedBox(width: AppSpacing.sectionGap),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.dashboardCategorizationActionTitle,
                        style: AppTypography.bodyStrong,
                      ),
                      const SizedBox(height: AppSpacing.hairline),
                      Text(
                        l10n.operationsReviewBanner(count),
                        style: AppTypography.caption,
                      ),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right, color: colors.textSecondary),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
