import 'package:flutter/material.dart';

import '../../../../core/localization/generated/app_localizations.dart';
import '../../../../core/theme_v1/app_theme_colors.dart';
import '../../../../core/theme_v1/app_dimensions.dart';
import '../../../../core/theme_v1/app_radius.dart';
import '../../../../core/theme_v1/app_spacing.dart';
import '../../../../core/theme_v1/app_typography.dart';

class BudgetSetupProgress extends StatelessWidget {
  const BudgetSetupProgress({
    required this.currentStep,
    required this.totalSteps,
    super.key,
  });

  final int currentStep;
  final int totalSteps;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final completedStep = currentStep + 1;
    final progress = totalSteps == 0 ? 0.0 : completedStep / totalSteps;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.budgetSetupStepProgress(completedStep, totalSteps),
          style: AppTypography.captionStrong,
        ),
        const SizedBox(height: AppSpacing.sm),
        ClipRRect(
          borderRadius: AppRadius.smRadius,
          child: LinearProgressIndicator(
            value: progress.clamp(0.0, 1.0).toDouble(),
            minHeight: AppDimensions.progressSmHeight,
            backgroundColor: context.appThemeColors.progressTrack,
            color: context.appThemeColors.primary,
          ),
        ),
      ],
    );
  }
}
