import 'package:flutter/material.dart';

import '../../../../core/formatters/app_money_formatter.dart';
import '../../../../core/icons/app_icons.dart';
import '../../../../core/theme_v1/app_theme_colors.dart';
import '../../../../core/theme_v1/app_radius.dart';
import '../../../../core/theme_v1/app_shadows.dart';
import '../../../../core/theme_v1/app_spacing.dart';
import '../../../../core/theme_v1/app_typography.dart';
import '../../domain/entities/operation.dart';
import 'operation_list_tile.dart';

class OperationDateSection extends StatelessWidget {
  const OperationDateSection({
    required this.date,
    required this.runningBalanceAfterDate,
    required this.operations,
    required this.onOperationTap,
    required this.onOperationArchive,
    super.key,
  });

  final String date;
  final double runningBalanceAfterDate;
  final List<Operation> operations;
  final ValueChanged<Operation> onOperationTap;
  final Future<bool> Function(Operation operation) onOperationArchive;

  @override
  Widget build(BuildContext context) {
    final colors = context.appThemeColors;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: AppRadius.cardRadius,
        boxShadow: AppShadows.card(context),
      ),
      child: Padding(
        padding: AppSpacing.compactListTileInsets,
        child: Column(
          children: [
            Padding(
              padding: AppSpacing.sectionHeaderInsets,
              child: Row(
                children: [
                  Expanded(
                    child: Text(date, style: AppTypography.captionStrong),
                  ),
                  Text(
                    formatMoney(
                      runningBalanceAfterDate,
                      _currencyCode(operations),
                      showPositiveSign: true,
                    ),
                    style: AppTypography.currencyStrong,
                  ),
                ],
              ),
            ),
            for (final entry in operations.indexed) ...[
              if (entry.$1 > 0)
                Divider(height: AppSpacing.none, color: colors.divider),
              Dismissible(
                key: ValueKey(entry.$2.id),
                direction: DismissDirection.endToStart,
                background: ColoredBox(
                  color: colors.error,
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: Padding(
                      padding: AppSpacing.cardInsets,
                      child: Icon(
                        AppIcons.actionArchive,
                        color: colors.textInverse,
                      ),
                    ),
                  ),
                ),
                confirmDismiss: (direction) {
                  return onOperationArchive(entry.$2);
                },
                child: OperationListTile(
                  operation: entry.$2,
                  onTap: () => onOperationTap(entry.$2),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _currencyCode(List<Operation> operations) {
    return operations.isEmpty ? 'CAD' : operations.first.currencyCode;
  }
}
