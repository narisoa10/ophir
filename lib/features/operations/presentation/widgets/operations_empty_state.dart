import 'package:flutter/material.dart';

import '../../../../core/localization/generated/app_localizations.dart';
import '../../../../core/theme_v1/app_spacing.dart';
import '../../../../core/theme_v1/app_typography.dart';

class OperationsEmptyState extends StatelessWidget {
  const OperationsEmptyState({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Center(
      child: Padding(
        padding: AppSpacing.screen,
        child: Text(
          l10n.operationsEmptyMessage,
          style: AppTypography.caption,
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}
