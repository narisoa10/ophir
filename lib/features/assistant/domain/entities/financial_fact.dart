import '../../../categories/domain/enums/category_analytics_group.dart';
import '../../../operations/domain/enums/operation_recurrence.dart';
import '../../../operations/domain/enums/operation_type.dart';
import 'financial_fact_confidence.dart';
import 'financial_fact_source.dart';
import 'financial_fact_type.dart';

final class FinancialFact {
  const FinancialFact({
    required this.id,
    required this.type,
    required this.source,
    required this.confidence,
    this.operationId,
    this.categoryId,
    this.accountId,
    this.userId,
    this.operationType,
    this.amount,
    this.currencyCode,
    this.occurredAt,
    this.recurrence,
    this.analyticsGroup,
  });

  final String id;
  final FinancialFactType type;
  final FinancialFactSource source;
  final FinancialFactConfidence confidence;
  final String? operationId;
  final String? categoryId;
  final String? accountId;
  final String? userId;
  final OperationType? operationType;
  final double? amount;
  final String? currencyCode;
  final DateTime? occurredAt;
  final OperationRecurrence? recurrence;
  final CategoryAnalyticsGroup? analyticsGroup;
}
