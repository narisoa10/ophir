import '../../domain/entities/operation.dart';
import '../../domain/enums/operation_recurrence.dart';
import '../../domain/enums/operation_source.dart';
import '../../domain/utils/operation_calendar_date.dart';
import 'operation_editor_result.dart';

Operation operationFromEditorResult({
  required OperationEditorResult result,
  required Operation? existingOperation,
}) {
  final now = DateTime.now().toUtc();
  final categoryChanged =
      existingOperation != null &&
      result.categoryId != existingOperation.categoryId;
  final categoryOverridden =
      existingOperation?.categoryOverridden == true || categoryChanged;

  return Operation(
    id: existingOperation?.id ?? '',
    userId: existingOperation?.userId ?? '',
    source: existingOperation?.source ?? OperationSource.manual,
    externalId: existingOperation?.externalId,
    isPending: existingOperation?.isPending ?? false,
    fromAccountId: existingOperation?.fromAccountId,
    toAccountId: existingOperation?.toAccountId,
    categoryId: result.categoryId,
    categoryOverridden: categoryOverridden,
    type: result.type!,
    amount: result.amount!,
    currencyCode: result.currencyCode!,
    occurredAt: operationCalendarDateValue(result.occurredAt!),
    recurrence: result.recurrence!,
    isRecurring: result.recurrence != OperationRecurrence.none,
    note: result.note,
    createdAt: existingOperation?.createdAt ?? now,
    updatedAt: now,
  );
}
