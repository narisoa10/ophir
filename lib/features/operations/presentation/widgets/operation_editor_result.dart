import '../../domain/enums/operation_recurrence.dart';
import '../../domain/enums/operation_type.dart';

final class OperationEditorResult {
  const OperationEditorResult._({
    required this.isArchived,
    this.type,
    this.amount,
    this.currencyCode,
    this.occurredAt,
    this.categoryId,
    this.recurrence,
    this.note,
  });

  const OperationEditorResult.saved({
    required OperationType type,
    required double amount,
    required String currencyCode,
    required DateTime occurredAt,
    required String? categoryId,
    required OperationRecurrence recurrence,
    required String? note,
  }) : this._(
         isArchived: false,
         type: type,
         amount: amount,
         currencyCode: currencyCode,
         occurredAt: occurredAt,
         categoryId: categoryId,
         recurrence: recurrence,
         note: note,
       );

  const OperationEditorResult.archived() : this._(isArchived: true);

  final bool isArchived;
  final OperationType? type;
  final double? amount;
  final String? currencyCode;
  final DateTime? occurredAt;
  final String? categoryId;
  final OperationRecurrence? recurrence;
  final String? note;
}
