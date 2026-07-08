import '../../../categories/domain/enums/category_financial_distribution_role.dart';
import '../../../categories/domain/enums/category_stable_key.dart';
import '../../../operations/domain/enums/operation_type.dart';
import 'financial_behavior_fact_kind.dart';

final class FinancialBehaviorFact {
  const FinancialBehaviorFact({
    required this.operationId,
    required this.operationType,
    required this.categoryId,
    required this.stableKey,
    required this.amount,
    required this.currencyCode,
    required this.occurredAt,
    required this.kind,
    required this.distributionRole,
    required this.requiresTransactionContext,
  });

  final String operationId;
  final OperationType operationType;
  final String? categoryId;
  final CategoryStableKey? stableKey;
  final double amount;
  final String currencyCode;
  final DateTime occurredAt;
  final FinancialBehaviorFactKind kind;
  final CategoryFinancialDistributionRole? distributionRole;
  final bool requiresTransactionContext;

  bool get isResolved {
    return kind != FinancialBehaviorFactKind.unresolved;
  }
}
