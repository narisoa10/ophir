import 'package:flutter/material.dart';

import '../../../../core/localization/generated/app_localizations.dart';
import '../../../../core/theme_v1/app_colors.dart';
import '../../../../core/theme_v1/app_dimensions.dart';
import '../../../../core/theme_v1/app_spacing.dart';
import '../../../../core/theme_v1/app_typography.dart';
import '../models/dashboard_presentation.dart';
import '../widgets/dashboard_presentation_builder.dart';

class DashboardDetailScaffold extends StatelessWidget {
  const DashboardDetailScaffold({
    required this.titleBuilder,
    required this.contentBuilder,
    super.key,
  });

  final String Function(AppLocalizations l10n) titleBuilder;
  final Widget Function(
    DashboardPresentation presentation,
    AppLocalizations l10n,
  )
  contentBuilder;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return ColoredBox(
      color: AppColors.background,
      child: ListView(
        padding: AppSpacing.screen,
        children: [
          Row(
            children: [
              IconButton(
                icon: const Icon(
                  Icons.arrow_back,
                  color: AppColors.iconPrimary,
                  size: AppDimensions.iconLg,
                ),
                onPressed: () => Navigator.of(context).maybePop(),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  titleBuilder(l10n),
                  style: AppTypography.screenTitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.screenGap),
          DashboardPresentationBuilder(
            builder: (context, presentation, l10n) {
              return contentBuilder(presentation, l10n);
            },
          ),
        ],
      ),
    );
  }
}
