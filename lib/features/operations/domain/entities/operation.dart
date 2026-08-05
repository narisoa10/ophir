import 'package:flutter/foundation.dart';

import '../enums/operation_recurrence.dart';
import '../enums/operation_type.dart';
import '../enums/operation_source.dart';

@immutable
final class Operation {
  const Operation({
    required this.id,
    required this.userId,
    required this.type,
    required this.amount,
    required this.currencyCode,
    required this.occurredAt,
    required this.recurrence,
    required this.isRecurring,
    required this.createdAt,
    required this.updatedAt,
    this.source = OperationSource.manual,
    this.externalId,
    this.isPending = false,
    this.fromAccountId,
    this.toAccountId,
    this.categoryId,
    this.note,
    this.categoryOverridden = false,
  });

  final String id;
  final String userId;

  final OperationSource source;
  final String? externalId;
  final bool isPending;

  final String? fromAccountId;
  final String? toAccountId;
  final String? categoryId;

  final OperationType type;
  final double amount;
  final String currencyCode;

  final DateTime occurredAt;

  final OperationRecurrence recurrence;
  final bool isRecurring;

  final String? note;

  final bool categoryOverridden;

  final DateTime createdAt;
  final DateTime updatedAt;
}
