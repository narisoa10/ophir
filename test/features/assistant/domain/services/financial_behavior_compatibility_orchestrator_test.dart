import 'package:flutter_test/flutter_test.dart';
import 'package:ophir/features/assistant/domain/entities/financial_model_period.dart';
import 'package:ophir/features/assistant/domain/services/financial_behavior_compatibility_orchestrator.dart';
import 'package:ophir/features/categories/domain/entities/category.dart';
import 'package:ophir/features/categories/domain/enums/category_analytics_group.dart';
import 'package:ophir/features/categories/domain/enums/category_stable_key.dart';
import 'package:ophir/features/categories/domain/enums/category_type.dart';
import 'package:ophir/features/categories/domain/enums/category_ui_group.dart';
import 'package:ophir/features/operations/domain/entities/operation.dart';
import 'package:ophir/features/operations/domain/enums/operation_recurrence.dart';
import 'package:ophir/features/operations/domain/enums/operation_type.dart';

void main() {
  const orchestrator = FinancialBehaviorCompatibilityOrchestrator();
  final period = FinancialModelPeriod(
    start: DateTime.utc(2026, 7),
    end: DateTime.utc(2026, 8),
  );

  group('FinancialBehaviorCompatibilityOrchestrator', () {
    test('builds financial behavior compatibility output', () {
      final rent = _category(
        id: 'rent',
        stableKey: CategoryStableKey.expenseHousingRent,
      );
      final savings = _category(
        id: 'savings',
        stableKey: CategoryStableKey.expenseFinanceSavings,
      );

      final output = orchestrator.build(
        operations: [
          _operation(id: 'rent', amount: 1000, categoryId: rent.id),
          _operation(id: 'savings', amount: 300, categoryId: savings.id),
        ],
        categories: [rent, savings],
        period: period,
      );

      expect(output.snapshot.facts, hasLength(2));
      expect(output.totals.legacyExpenseTotal, 1300);
      expect(output.totals.ordinarySpendingTotal, 1000);
      expect(output.totals.assetBuildingTotal, 300);
      expect(output.totals.behavioralSavingsTotal, 300);
      expect(output.totals.legacyVsIntelligenceDifference, 300);
    });

    test('broad legacy categories remain unresolved', () {
      final broadLegacy = _category(
        id: 'utilities',
        nameKey: 'categoryUtilities',
        stableKey: null,
      );

      final output = orchestrator.build(
        operations: [
          _operation(id: 'utilities', amount: 200, categoryId: broadLegacy.id),
        ],
        categories: [broadLegacy],
        period: period,
      );

      expect(output.snapshot.unresolvedCount, 1);
      expect(output.totals.unresolvedCount, 1);
      expect(output.totals.legacyExpenseTotal, 200);
      expect(output.totals.ordinarySpendingTotal, 0);
    });

    test('context required total remains overlay', () {
      final creditCard = _category(
        id: 'credit-card',
        stableKey: CategoryStableKey.expenseFinanceCreditCardPayment,
      );
      final autoLoan = _category(
        id: 'auto-loan',
        stableKey: CategoryStableKey.expenseTransportationAutoLoan,
      );

      final output = orchestrator.build(
        operations: [
          _operation(id: 'credit-card', amount: 600, categoryId: creditCard.id),
          _operation(id: 'auto-loan', amount: 500, categoryId: autoLoan.id),
        ],
        categories: [creditCard, autoLoan],
        period: period,
      );

      expect(output.totals.debtReductionTotal, 1100);
      expect(output.totals.contextRequiredTotal, 1100);
      expect(output.totals.ordinarySpendingTotal, 0);
    });
  });
}

Category _category({
  required String id,
  required CategoryStableKey? stableKey,
  CategoryType type = CategoryType.expense,
  String nameKey = 'categoryUnknownLegacy',
}) {
  final now = DateTime.utc(2026);

  return Category(
    id: id,
    type: type,
    uiGroup: type == CategoryType.income
        ? CategoryUiGroup.income
        : CategoryUiGroup.dailyLife,
    analyticsGroup: type == CategoryType.income
        ? CategoryAnalyticsGroup.income
        : CategoryAnalyticsGroup.flexibleExpenses,
    nameKey: nameKey,
    iconKey: 'other',
    colorKey: 'blue',
    sortOrder: 0,
    isActive: true,
    createdAt: now,
    updatedAt: now,
    exampleKey: 'categoryExampleDefault',
    stableKey: stableKey?.toJson(),
  );
}

Operation _operation({
  required String id,
  required double amount,
  required String? categoryId,
  OperationType type = OperationType.expense,
}) {
  final now = DateTime.utc(2026, 7, 10);

  return Operation(
    id: id,
    userId: 'user-id',
    type: type,
    amount: amount,
    currencyCode: 'CAD',
    occurredAt: now,
    recurrence: OperationRecurrence.none,
    isRecurring: false,
    createdAt: now,
    updatedAt: now,
    categoryId: categoryId,
  );
}
