import '../../domain/entities/operation.dart';
import '../../domain/enums/operation_type.dart';
import '../dto/operation_dto.dart';
import '../../domain/enums/operation_recurrence.dart';

extension OperationDtoMapper on OperationDto {
  Operation toEntity() {
    return Operation(
      id: id,
      userId: userId,
      fromAccountId: fromAccountId,
      toAccountId: toAccountId,
      categoryId: categoryId,
      type: OperationType.fromJson(type),
      amount: amount,
      currencyCode: currencyCode,
      occurredAt: occurredAt,
      isRecurring: isRecurring,
      note: note,
      createdAt: createdAt,
      updatedAt: updatedAt,
      recurrence: OperationRecurrence.fromJson(recurrence),
    );
  }
}

extension OperationEntityMapper on Operation {
  OperationDto toDto() {
    return OperationDto(
      id: id,
      userId: userId,
      fromAccountId: fromAccountId,
      toAccountId: toAccountId,
      categoryId: categoryId,
      type: type.toJson(),
      amount: amount,
      currencyCode: currencyCode,
      occurredAt: occurredAt,
      isRecurring: isRecurring,
      note: note,
      createdAt: createdAt,
      updatedAt: updatedAt,
      recurrence: recurrence.toJson(),
    );
  }
}
