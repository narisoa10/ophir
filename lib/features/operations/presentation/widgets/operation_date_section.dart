import 'package:flutter/material.dart';

import '../../../../core/theme_v1/app_colors.dart';
import '../../../../core/theme_v1/app_radius.dart';
import '../../../../core/theme_v1/app_shadows.dart';
import '../../../../core/theme_v1/app_spacing.dart';
import '../../../../core/theme_v1/app_typography.dart';
import '../models/operation_presentation.dart';
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
  final String runningBalanceAfterDate;
  final List<OperationPresentation> operations;
  final ValueChanged<OperationPresentation> onOperationTap;
  final Future<bool> Function(OperationPresentation operation)
  onOperationArchive;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.cardRadius,
        boxShadow: AppShadows.card,
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
                    runningBalanceAfterDate,
                    style: AppTypography.currencyStrong,
                  ),
                ],
              ),
            ),
            for (final entry in operations.indexed) ...[
              if (entry.$1 > 0)
                const Divider(
                  height: AppSpacing.none,
                  color: AppColors.dividerColor,
                ),
              Dismissible(
                key: ValueKey(entry.$2.operation.id),
                direction: DismissDirection.endToStart,
                background: const ColoredBox(
                  color: AppColors.error,
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: Padding(
                      padding: AppSpacing.cardInsets,
                      child: Icon(
                        Icons.archive_outlined,
                        color: AppColors.textInverse,
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
}
