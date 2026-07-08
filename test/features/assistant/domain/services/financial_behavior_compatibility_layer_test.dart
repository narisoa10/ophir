import 'package:flutter_test/flutter_test.dart';
import 'package:ophir/features/assistant/domain/entities/financial_behavior_compatibility_output.dart';
import 'package:ophir/features/assistant/domain/entities/financial_behavior_fact_kind.dart';
import 'package:ophir/features/assistant/domain/entities/financial_behavior_model_type.dart';
import 'package:ophir/features/assistant/domain/entities/financial_model_period.dart';
import 'package:ophir/features/assistant/domain/services/financial_behavior_facts_service.dart';
import 'package:ophir/features/assistant/domain/services/financial_behavior_totals_service.dart';
import 'package:ophir/features/categories/domain/entities/category.dart';
import 'package:ophir/features/categories/domain/enums/category_analytics_group.dart';
import 'package:ophir/features/categories/domain/enums/category_stable_key.dart';
import 'package:ophir/features/categories/domain/enums/category_type.dart';
import 'package:ophir/features/categories/domain/enums/category_ui_group.dart';
import 'package:ophir/features/operations/domain/entities/operation.dart';
import 'package:ophir/features/operations/domain/enums/operation_recurrence.dart';
import 'package:ophir/features/operations/domain/enums/operation_type.dart';

void main() {
  const factsService = FinancialBehaviorFactsService();
  const totalsService = FinancialBehaviorTotalsService();
  final period = FinancialModelPeriod(
    start: DateTime.utc(2026, 7),
    end: DateTime.utc(2026, 8),
  );

  group('Financial behavior compatibility layer', () {
    test('ordinary categories go to ordinarySpendingTotal', () {
      final rent = _category(
        id: 'rent',
        stableKey: CategoryStableKey.expenseHousingRent,
      );
      final groceries = _category(
        id: 'groceries',
        stableKey: CategoryStableKey.expenseFoodGroceries,
      );

      final output = _outputFor(
        factsService: factsService,
        totalsService: totalsService,
        period: period,
        categories: [rent, groceries],
        operations: [
          _operation(id: 'rent', amount: 1200, categoryId: rent.id),
          _operation(id: 'groceries', amount: 300, categoryId: groceries.id),
        ],
      );

      expect(output.totals.legacyExpenseTotal, 1500);
      expect(output.totals.ordinarySpendingTotal, 1500);
      expect(output.totals.legacyVsIntelligenceDifference, 0);
      expect(
        output.valueFor(
          FinancialBehaviorModelType.intelligenceOrdinarySpendingTotal,
        ),
        1500,
      );
    });

    test(
      'savings and registered contributions go to asset and savings totals',
      () {
        final categories = [
          _category(
            id: 'savings',
            stableKey: CategoryStableKey.expenseFinanceSavings,
          ),
          _category(
            id: 'investments',
            stableKey: CategoryStableKey.expenseFinanceInvestments,
          ),
          _category(
            id: 'tfsa',
            stableKey: CategoryStableKey.expenseFinanceTfsaContribution,
          ),
          _category(
            id: 'rrsp',
            stableKey: CategoryStableKey.expenseFinanceRrspContribution,
          ),
          _category(
            id: 'resp',
            stableKey: CategoryStableKey.expenseFinanceRespContribution,
          ),
          _category(
            id: 'emergency',
            stableKey: CategoryStableKey.expenseFinanceEmergencyFund,
          ),
        ];

        final output = _outputFor(
          factsService: factsService,
          totalsService: totalsService,
          period: period,
          categories: categories,
          operations: [
            for (final category in categories)
              _operation(id: category.id, amount: 100, categoryId: category.id),
          ],
        );

        expect(output.totals.ordinarySpendingTotal, 0);
        expect(output.totals.assetBuildingTotal, 600);
        expect(output.totals.behavioralSavingsTotal, 600);
        expect(
          output.valueFor(FinancialBehaviorModelType.behavioralSavingsTotal),
          600,
        );
      },
    );

    test('debt repayment goes to debtReductionTotal', () {
      final debt = _category(
        id: 'debt',
        stableKey: CategoryStableKey.expenseFinanceDebtRepayment,
      );

      final output = _outputFor(
        factsService: factsService,
        totalsService: totalsService,
        period: period,
        categories: [debt],
        operations: [_operation(id: 'debt', amount: 250, categoryId: debt.id)],
      );

      expect(output.totals.ordinarySpendingTotal, 0);
      expect(output.totals.debtReductionTotal, 250);
      expect(output.totals.contextRequiredTotal, 0);
    });

    test('credit card and loan payments are context-required overlay', () {
      final creditCard = _category(
        id: 'credit-card',
        stableKey: CategoryStableKey.expenseFinanceCreditCardPayment,
      );
      final loan = _category(
        id: 'loan',
        stableKey: CategoryStableKey.expenseFinanceLoanPayment,
      );

      final output = _outputFor(
        factsService: factsService,
        totalsService: totalsService,
        period: period,
        categories: [creditCard, loan],
        operations: [
          _operation(id: 'credit-card', amount: 600, categoryId: creditCard.id),
          _operation(id: 'loan', amount: 400, categoryId: loan.id),
        ],
      );

      expect(output.totals.debtReductionTotal, 1000);
      expect(output.totals.contextRequiredTotal, 1000);
      expect(output.totals.ordinarySpendingTotal, 0);
    });

    test('cash withdrawal goes to cashMovementTotal', () {
      final cash = _category(
        id: 'cash',
        stableKey: CategoryStableKey.expenseOtherCashWithdrawal,
      );

      final output = _outputFor(
        factsService: factsService,
        totalsService: totalsService,
        period: period,
        categories: [cash],
        operations: [_operation(id: 'cash', amount: 80, categoryId: cash.id)],
      );

      expect(output.totals.cashMovementTotal, 80);
      expect(output.totals.contextRequiredTotal, 80);
      expect(output.totals.ordinarySpendingTotal, 0);
    });

    test('adjustment goes to dataAdjustmentTotal', () {
      final adjustment = _category(
        id: 'adjustment',
        stableKey: CategoryStableKey.expenseOtherAdjustment,
      );

      final output = _outputFor(
        factsService: factsService,
        totalsService: totalsService,
        period: period,
        categories: [adjustment],
        operations: [
          _operation(id: 'adjustment', amount: 40, categoryId: adjustment.id),
        ],
      );

      expect(output.totals.dataAdjustmentTotal, 40);
      expect(output.totals.contextRequiredTotal, 40);
      expect(output.totals.ordinarySpendingTotal, 0);
    });

    test('currency exchange is context-required cash movement', () {
      final exchange = _category(
        id: 'exchange',
        stableKey: CategoryStableKey.expenseFinanceCurrencyExchange,
      );

      final output = _outputFor(
        factsService: factsService,
        totalsService: totalsService,
        period: period,
        categories: [exchange],
        operations: [
          _operation(id: 'exchange', amount: 30, categoryId: exchange.id),
        ],
      );

      expect(output.totals.cashMovementTotal, 30);
      expect(output.totals.contextRequiredTotal, 30);
      expect(output.totals.ordinarySpendingTotal, 0);
    });

    test('auto loan is context-required debt behavior', () {
      final autoLoan = _category(
        id: 'auto-loan',
        stableKey: CategoryStableKey.expenseTransportationAutoLoan,
      );

      final output = _outputFor(
        factsService: factsService,
        totalsService: totalsService,
        period: period,
        categories: [autoLoan],
        operations: [
          _operation(id: 'auto-loan', amount: 500, categoryId: autoLoan.id),
        ],
      );

      expect(output.totals.debtReductionTotal, 500);
      expect(output.totals.contextRequiredTotal, 500);
      expect(output.totals.ordinarySpendingTotal, 0);
    });

    test('broad legacy category is unresolved and does not crash', () {
      final broadLegacy = _category(
        id: 'utilities',
        nameKey: 'categoryUtilities',
        stableKey: null,
      );

      final snapshot = factsService.buildSnapshot(
        operations: [
          _operation(id: 'utilities', amount: 200, categoryId: broadLegacy.id),
        ],
        categories: [broadLegacy],
      );
      final totals = totalsService.totalsFor(
        snapshot: snapshot,
        period: period,
      );

      expect(snapshot.unresolvedCount, 1);
      expect(snapshot.facts.single.kind, FinancialBehaviorFactKind.unresolved);
      expect(totals.unresolvedCount, 1);
      expect(totals.legacyExpenseTotal, 200);
      expect(totals.ordinarySpendingTotal, 0);
    });

    test(
      'invalid stableKey is unresolved and does not fallback to nameKey',
      () {
        final invalid = _category(
          id: 'invalid',
          nameKey: 'categoryGroceries',
          stableKey: 'expense.food.invalid',
        );

        final snapshot = factsService.buildSnapshot(
          operations: [
            _operation(id: 'invalid', amount: 100, categoryId: invalid.id),
          ],
          categories: [invalid],
        );
        final totals = totalsService.totalsFor(
          snapshot: snapshot,
          period: period,
        );

        expect(snapshot.unresolvedCount, 1);
        expect(snapshot.facts.single.stableKey, isNull);
        expect(totals.legacyExpenseTotal, 100);
        expect(totals.ordinarySpendingTotal, 0);
        expect(totals.legacyVsIntelligenceDifference, 100);
      },
    );

    test('income facts are available but do not affect expense totals', () {
      final salary = _category(
        id: 'salary',
        type: CategoryType.income,
        stableKey: CategoryStableKey.incomeEmploymentSalary,
      );

      final output = _outputFor(
        factsService: factsService,
        totalsService: totalsService,
        period: period,
        categories: [salary],
        operations: [
          _operation(
            id: 'salary',
            amount: 5000,
            categoryId: salary.id,
            type: OperationType.income,
          ),
        ],
      );

      expect(
        output.snapshot.facts.single.kind,
        FinancialBehaviorFactKind.income,
      );
      expect(output.totals.legacyExpenseTotal, 0);
      expect(output.totals.ordinarySpendingTotal, 0);
    });
  });
}

FinancialBehaviorCompatibilityOutput _outputFor({
  required FinancialBehaviorFactsService factsService,
  required FinancialBehaviorTotalsService totalsService,
  required FinancialModelPeriod period,
  required List<Operation> operations,
  required List<Category> categories,
}) {
  final snapshot = factsService.buildSnapshot(
    operations: operations,
    categories: categories,
  );

  return totalsService.outputFor(snapshot: snapshot, period: period);
}

Category _category({
  required String id,
  required Object? stableKey,
  CategoryType type = CategoryType.expense,
  String nameKey = 'categoryUnknownLegacy',
}) {
  final now = DateTime.utc(2026);
  final stableKeyValue = stableKey is CategoryStableKey
      ? stableKey.toJson()
      : stableKey as String?;

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
    stableKey: stableKeyValue,
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
