import '../../../../core/localization/generated/app_localizations.dart';
import '../../domain/enums/operation_recurrence.dart';

final class OperationRecurrenceAdapter {
  const OperationRecurrenceAdapter();

  String label(OperationRecurrence recurrence, AppLocalizations l10n) {
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
