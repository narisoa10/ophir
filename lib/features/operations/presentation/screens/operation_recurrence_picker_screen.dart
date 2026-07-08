import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/icons/app_icons.dart';
import '../../../../core/localization/generated/app_localizations.dart';
import '../../../../core/theme_v1/app_colors.dart';
import '../../../../core/theme_v1/app_radius.dart';
import '../../../../core/theme_v1/app_spacing.dart';
import '../../../../core/theme_v1/app_typography.dart';
import '../../domain/enums/operation_recurrence.dart';
import '../adapters/operation_recurrence_adapter.dart';
import '../widgets/operation_app_bar.dart';

class OperationRecurrencePickerScreen extends StatelessWidget {
  const OperationRecurrencePickerScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    const adapter = OperationRecurrenceAdapter();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: OperationAppBar(title: l10n.operationRecurrenceTitle),
      body: SafeArea(
        child: ListView.separated(
          padding: AppSpacing.screen,
          itemCount: OperationRecurrence.values.length,
          separatorBuilder: (context, index) {
            return const SizedBox(height: AppSpacing.inlineGap);
          },
          itemBuilder: (context, index) {
            final recurrence = OperationRecurrence.values[index];

            return ListTile(
              tileColor: AppColors.surface,
              contentPadding: AppSpacing.listTileInsets,
              shape: AppRadius.cardShape,
              title: Text(
                adapter.label(recurrence, l10n),
                style: AppTypography.body,
              ),
              trailing: const Icon(
                AppIcons.actionChevronRight,
                color: AppColors.iconTertiary,
              ),
              onTap: () => context.pop(recurrence),
            );
          },
        ),
      ),
    );
  }
}
