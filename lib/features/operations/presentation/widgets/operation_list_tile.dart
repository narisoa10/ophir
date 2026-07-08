import 'package:flutter/material.dart';

import '../../../../core/theme_v1/app_dimensions.dart';
import '../../../../core/theme_v1/app_spacing.dart';
import '../../../../core/theme_v1/app_typography.dart';
import '../models/operation_presentation.dart';
import 'operation_icon_badge.dart';

class OperationListTile extends StatelessWidget {
  const OperationListTile({required this.operation, this.onTap, super.key});

  final OperationPresentation operation;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: AppSpacing.listTileInsets,
        child: Row(
          children: [
            OperationIconBadge(
              size: AppDimensions.avatarSm,
              icon: operation.icon,
              iconSize: AppDimensions.iconSm,
              iconColor: operation.color,
              backgroundColor: operation.backgroundColor,
            ),
            const SizedBox(width: AppSpacing.sectionGap),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    operation.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.bodyStrong,
                  ),
                  const SizedBox(height: AppSpacing.hairline),
                  Text(
                    operation.subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.caption,
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.inlineGap),
            Text(operation.amount, style: AppTypography.currency),
          ],
        ),
      ),
    );
  }
}
