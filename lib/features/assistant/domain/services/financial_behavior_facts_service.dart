import '../../../categories/domain/entities/category.dart';
import '../../../categories/domain/entities/category_financial_behavior.dart';
import '../../../categories/domain/services/category_financial_behavior_policy.dart';
import '../../../operations/domain/entities/operation.dart';
import '../../../operations/domain/enums/operation_type.dart';
import '../entities/financial_behavior_fact.dart';
import '../entities/financial_behavior_fact_kind.dart';
import '../entities/financial_behavior_facts_snapshot.dart';

final class FinancialBehaviorFactsService {
  const FinancialBehaviorFactsService({
    CategoryFinancialBehaviorPolicy behaviorPolicy =
        const CategoryFinancialBehaviorPolicy(),
  }) : _behaviorPolicy = behaviorPolicy;

  final CategoryFinancialBehaviorPolicy _behaviorPolicy;

  FinancialBehaviorFactsSnapshot buildSnapshot({
    required List<Operation> operations,
    required List<Category> categories,
  }) {
    final categoryById = {
      for (final category in categories) category.id: category,
    };
    final facts = <FinancialBehaviorFact>[];

    for (final operation in operations) {
      if (operation.type == OperationType.transfer) {
        continue;
      }

      final category = categoryById[operation.categoryId];
      final behavior = category == null
          ? null
          : _behaviorPolicy.behaviorFor(category);

      facts.add(_factFor(operation: operation, behavior: behavior));
    }

    return FinancialBehaviorFactsSnapshot(facts: facts);
  }

  FinancialBehaviorFact _factFor({
    required Operation operation,
    required CategoryFinancialBehavior? behavior,
  }) {
    return FinancialBehaviorFact(
      operationId: operation.id,
      operationType: operation.type,
      categoryId: operation.categoryId,
      stableKey: behavior?.profile.stableKey,
      amount: operation.amount,
      currencyCode: operation.currencyCode,
      occurredAt: operation.occurredAt,
      kind: _kindFor(operation: operation, behavior: behavior),
      distributionRole: behavior?.distributionRole,
      requiresTransactionContext: behavior?.requiresTransactionContext ?? false,
    );
  }

  FinancialBehaviorFactKind _kindFor({
    required Operation operation,
    required CategoryFinancialBehavior? behavior,
  }) {
    if (behavior == null) {
      return FinancialBehaviorFactKind.unresolved;
    }

    if (operation.type == OperationType.income) {
      return FinancialBehaviorFactKind.income;
    }

    if (behavior.isOrdinarySpending) {
      return FinancialBehaviorFactKind.ordinarySpending;
    }
    if (behavior.isAssetBuilding) {
      return FinancialBehaviorFactKind.assetBuilding;
    }
    if (behavior.isDebtReduction) {
      return FinancialBehaviorFactKind.debtReduction;
    }
    if (behavior.isCashMovement) {
      return FinancialBehaviorFactKind.cashMovement;
    }
    if (behavior.isDataAdjustment) {
      return FinancialBehaviorFactKind.dataAdjustment;
    }

    return FinancialBehaviorFactKind.unresolved;
  }
}
