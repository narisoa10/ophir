import 'package:flutter/material.dart';

import '../../../../core/categories/app_categories.dart';
import '../../../../core/formatters/app_money_formatter.dart';
import '../../../../core/icons/app_category_icons.dart';
import '../../../../core/icons/app_icons.dart';
import '../../../../core/localization/generated/app_localizations.dart';
import '../../../../core/theme_v1/app_category_colors.dart';
import '../../../../core/theme_v1/app_theme_colors.dart';
import '../../../../core/theme_v1/app_dimensions.dart';
import '../../../../core/theme_v1/app_spacing.dart';
import '../../../../core/theme_v1/app_typography.dart';
import '../../domain/entities/operation.dart';
import '../../domain/enums/operation_type.dart';
import '../../domain/utils/operation_needs_categorization.dart';
import '../models/operation_display_labels.dart';
import 'operation_icon_badge.dart';

class OperationListTile extends StatelessWidget {
  const OperationListTile({required this.operation, this.onTap, super.key});

  final Operation operation;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = context.appThemeColors;
    final category = AppCategories.byIdName(operation.categoryId);
    final labels = OperationDisplayLabels.forOperation(operation, l10n);
    final colorKey = category?.colorKey ?? _colorKey(operation.type);
    final needsReview = operationNeedsCategorization(operation);

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: AppSpacing.listTileInsets,
        child: Row(
          children: [
            OperationIconBadge(
              size: AppDimensions.avatarSm,
              icon: category == null
                  ? _fallbackIcon(operation.type)
                  : AppCategoryIcons.fromKey(category.iconKey),
              iconSize: AppDimensions.iconSm,
              iconColor: AppCategoryColors.fromKey(colors, colorKey),
              backgroundColor: AppCategoryColors.backgroundFromKey(
                colors,
                colorKey,
              ),
            ),
            const SizedBox(width: AppSpacing.sectionGap),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    labels.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.bodyStrong,
                  ),
                  if (operation.isPending) ...[
                    const SizedBox(height: AppSpacing.hairline),
                    Text(
                      l10n.operationPendingBadge,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.caption.copyWith(
                        color: colors.textSecondary,
                      ),
                    ),
                  ] else if (needsReview) ...[
                    const SizedBox(height: AppSpacing.hairline),
                    Text(
                      l10n.operationNeedsCategorizationBadge,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.caption.copyWith(
                        color: colors.primary,
                      ),
                    ),
                  ] else if (labels.subtitle.isNotEmpty) ...[
                    const SizedBox(height: AppSpacing.hairline),
                    Text(
                      labels.subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.caption,
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.inlineGap),
            Text(_formattedAmount(operation), style: AppTypography.currency),
          ],
        ),
      ),
    );
  }

  IconData _fallbackIcon(OperationType type) {
    return switch (type) {
      OperationType.expense => AppIcons.operationExpense,
      OperationType.income => AppIcons.operationIncome,
      OperationType.transfer => AppIcons.navigationOperations,
    };
  }

  String _colorKey(OperationType type) {
    return switch (type) {
      OperationType.expense => AppCategoryColors.red,
      OperationType.income => AppCategoryColors.green,
      OperationType.transfer => AppCategoryColors.blue,
    };
  }

  String _formattedAmount(Operation operation) {
    final signedAmount = switch (operation.type) {
      OperationType.expense => -operation.amount,
      OperationType.income => operation.amount,
      OperationType.transfer => operation.amount,
    };

    return formatMoney(
      signedAmount,
      operation.currencyCode,
      showPositiveSign: operation.type == OperationType.income,
    );
  }
}
