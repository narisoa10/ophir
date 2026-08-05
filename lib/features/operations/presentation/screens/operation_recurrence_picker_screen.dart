import 'package:flutter/material.dart';

import '../../../../core/localization/generated/app_localizations.dart';
import '../../../../core/theme_v1/app_theme_colors.dart';
import '../../domain/enums/operation_recurrence.dart';

class OperationRecurrencePickerScreen extends StatelessWidget {
  const OperationRecurrencePickerScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      backgroundColor: context.appThemeColors.background,
      appBar: AppBar(
        backgroundColor: context.appThemeColors.background,
        title: Text(l10n.operationRecurrenceTitle),
      ),
      body: ListView(
        children: [
          for (final recurrence in OperationRecurrence.values)
            ListTile(
              title: Text(_label(recurrence, l10n)),
              onTap: () => Navigator.of(context).pop(recurrence),
            ),
        ],
      ),
    );
  }

  String _label(OperationRecurrence recurrence, AppLocalizations l10n) {
    return switch (recurrence) {
      OperationRecurrence.none => l10n.operationRecurrenceNone,
      OperationRecurrence.daily => l10n.operationRecurrenceDaily,
      OperationRecurrence.weekly => l10n.operationRecurrenceWeekly,
      OperationRecurrence.biweekly => l10n.operationRecurrenceBiweekly,
      OperationRecurrence.monthly => l10n.operationRecurrenceMonthly,
      OperationRecurrence.yearly => l10n.operationRecurrenceYearly,
    };
  }
}
