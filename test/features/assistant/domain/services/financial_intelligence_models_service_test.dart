import 'package:flutter_test/flutter_test.dart';
import 'package:ophir/features/assistant/domain/entities/financial_behavior_compatibility_output.dart';
import 'package:ophir/features/assistant/domain/entities/financial_intelligence_model_type.dart';
import 'package:ophir/features/assistant/domain/entities/financial_model_period.dart';
import 'package:ophir/features/assistant/domain/services/financial_behavior_facts_service.dart';
import 'package:ophir/features/assistant/domain/services/financial_behavior_totals_service.dart';
import 'package:ophir/features/assistant/domain/services/financial_intelligence_models_service.dart';
import 'package:ophir/features/categories/domain/entities/category.dart';
import 'package:ophir/features/categories/domain/enums/category_analytics_group.dart';
import 'package:ophir/features/categories/domain/enums/category_stable_key.dart';
import 'package:ophir/features/categories/domain/enums/category_type.dart';
import 'package:ophir/features/categories/domain/enums/category_ui_group.dart';
import 'package:ophir/features/operations/domain/entities/operation.dart';
import 'package:ophir/features/operations/domain/enums/operation_recurrence.dart';
import 'package:ophir/features/operations/domain/enums/operation_type.dart';

void main() {
  const service = FinancialIntelligenceModelsService();
  final period = FinancialModelPeriod(
    start: DateTime.utc(2026, 7),
    end: DateTime.utc(2026, 8),
  );

  group('FinancialIntelligenceModelsService', () {
    test('ordinary spending excludes asset debt cash and data actions', () {
      final rent = _category(
        id: 'rent',
        stableKey: CategoryStableKey.expenseHousingRent,
      );
      final savings = _category(
        id: 'savings',
        stableKey: CategoryStableKey.expenseFinanceSavings,
      );
      final debt = _category(
        id: 'debt',
        stableKey: CategoryStableKey.expenseFinanceDebtRepayment,
      );
      final cash = _category(
        id: 'cash',
        stableKey: CategoryStableKey.expenseOtherCashWithdrawal,
      );
      final adjustment = _category(
        id: 'adjustment',
        stableKey: CategoryStableKey.expenseOtherAdjustment,
      );
      final output = _outputFor(
        period: period,
        categories: [rent, savings, debt, cash, adjustment],
        operations: [
          _operation(id: 'rent', amount: 1000, categoryId: rent.id),
          _operation(id: 'savings', amount: 500, categoryId: savings.id),
          _operation(id: 'debt', amount: 200, categoryId: debt.id),
          _operation(id: 'cash', amount: 100, categoryId: cash.id),
          _operation(id: 'adjustment', amount: 50, categoryId: adjustment.id),
        ],
      );

      final models = service.build(
        output: output,
        period: period,
        incomeTotal: 5000,
      );

      expect(
        models.valueFor(FinancialIntelligenceModelType.ordinarySpendingTotal),
        1000,
      );
      expect(
        models.valueFor(FinancialIntelligenceModelType.assetBuildingTotal),
        500,
      );
      expect(
        models.valueFor(FinancialIntelligenceModelType.debtReductionTotal),
        200,
      );
      expect(
        models.valueFor(FinancialIntelligenceModelType.cashMovementTotal),
        100,
      );
      expect(
        models.valueFor(FinancialIntelligenceModelType.dataAdjustmentTotal),
        50,
      );
    });

    test(
      'mandatory flexible and discretionary totals use distribution role',
      () {
        final rent = _category(
          id: 'rent',
          stableKey: CategoryStableKey.expenseHousingRent,
        );
        final haircare = _category(
          id: 'haircare',
          stableKey: CategoryStableKey.expensePersonalCareHaircare,
        );
        final movies = _category(
          id: 'movies',
          stableKey: CategoryStableKey.expenseEntertainmentLifestyleMovies,
        );
        final output = _outputFor(
          period: period,
          categories: [rent, haircare, movies],
          operations: [
            _operation(id: 'rent', amount: 1200, categoryId: rent.id),
            _operation(id: 'haircare', amount: 80, categoryId: haircare.id),
            _operation(id: 'movies', amount: 40, categoryId: movies.id),
          ],
        );

        final models = service.build(
          output: output,
          period: period,
          incomeTotal: 4000,
        );

        expect(
          models.valueFor(
            FinancialIntelligenceModelType.mandatorySpendingTotal,
          ),
          1200,
        );
        expect(
          models.valueFor(FinancialIntelligenceModelType.flexibleSpendingTotal),
          80,
        );
        expect(
          models.valueFor(
            FinancialIntelligenceModelType.discretionarySpendingTotal,
          ),
          40,
        );
      },
    );

    test('distribution totals use the requested period', () {
      final rent = _category(
        id: 'rent',
        stableKey: CategoryStableKey.expenseHousingRent,
      );
      final output = _outputFor(
        period: period,
        categories: [rent],
        operations: [
          _operation(
            id: 'current-rent',
            amount: 1200,
            categoryId: rent.id,
          ),
          _operation(
            id: 'previous-rent',
            amount: 900,
            categoryId: rent.id,
            occurredAt: DateTime.utc(2026, 6, 30),
          ),
        ],
      );

      final models = service.build(
        output: output,
        period: period,
        incomeTotal: 4000,
      );

      expect(
        models.valueFor(FinancialIntelligenceModelType.ordinarySpendingTotal),
        1200,
      );
      expect(
        models.valueFor(
          FinancialIntelligenceModelType.mandatorySpendingTotal,
        ),
        1200,
      );
    });

    test('context required remains overlay total', () {
      final creditCard = _category(
        id: 'credit-card',
        stableKey: CategoryStableKey.expenseFinanceCreditCardPayment,
      );
      final output = _outputFor(
        period: period,
        categories: [creditCard],
        operations: [
          _operation(id: 'credit-card', amount: 600, categoryId: creditCard.id),
        ],
      );

      final models = service.build(
        output: output,
        period: period,
        incomeTotal: 5000,
      );

      expect(
        models.valueFor(FinancialIntelligenceModelType.debtReductionTotal),
        600,
      );
      expect(
        models.valueFor(FinancialIntelligenceModelType.contextRequiredTotal),
        600,
      );
      expect(
        models.valueFor(FinancialIntelligenceModelType.ordinarySpendingTotal),
        0,
      );
    });

    test('ratios use income denominator', () {
      final rent = _category(
        id: 'rent',
        stableKey: CategoryStableKey.expenseHousingRent,
      );
      final groceries = _category(
        id: 'groceries',
        stableKey: CategoryStableKey.expenseFoodGroceries,
      );
      final movies = _category(
        id: 'movies',
        stableKey: CategoryStableKey.expenseEntertainmentLifestyleMovies,
      );
      final output = _outputFor(
        period: period,
        categories: [rent, groceries, movies],
        operations: [
          _operation(id: 'rent', amount: 1000, categoryId: rent.id),
          _operation(id: 'groceries', amount: 500, categoryId: groceries.id),
          _operation(id: 'movies', amount: 100, categoryId: movies.id),
        ],
      );

      final models = service.build(
        output: output,
        period: period,
        incomeTotal: 5000,
      );

      expect(
        models.valueFor(FinancialIntelligenceModelType.ordinarySpendingRatio),
        1600 / 5000,
      );
      expect(
        models.valueFor(FinancialIntelligenceModelType.mandatoryRatio),
        1500 / 5000,
      );
      expect(
        models.valueFor(FinancialIntelligenceModelType.discretionaryRatio),
        100 / 5000,
      );
    });

    test('zero income is safe for ratios', () {
      final rent = _category(
        id: 'rent',
        stableKey: CategoryStableKey.expenseHousingRent,
      );
      final output = _outputFor(
        period: period,
        categories: [rent],
        operations: [_operation(id: 'rent', amount: 1000, categoryId: rent.id)],
      );

      final models = service.build(
        output: output,
        period: period,
        incomeTotal: 0,
      );

      expect(
        models.valueFor(FinancialIntelligenceModelType.ordinarySpendingRatio),
        0,
      );
      expect(models.valueFor(FinancialIntelligenceModelType.mandatoryRatio), 0);
    });

    test(
      'unresolved behavior is safe and excluded from intelligence totals',
      () {
        final broadLegacy = _category(
          id: 'utilities',
          stableKey: null,
          nameKey: 'categoryUtilities',
        );
        final output = _outputFor(
          period: period,
          categories: [broadLegacy],
          operations: [
            _operation(
              id: 'utilities',
              amount: 200,
              categoryId: broadLegacy.id,
            ),
          ],
        );

        final models = service.build(
          output: output,
          period: period,
          incomeTotal: 5000,
        );

        expect(output.totals.unresolvedCount, 1);
        expect(
          models.valueFor(FinancialIntelligenceModelType.ordinarySpendingTotal),
          0,
        );
        expect(
          models.valueFor(
            FinancialIntelligenceModelType.mandatorySpendingTotal,
          ),
          0,
        );
      },
    );

    test('snapshot contains all additive intelligence model types', () {
      final output = _outputFor(
        period: period,
        categories: const [],
        operations: const [],
      );

      final models = service.build(
        output: output,
        period: period,
        incomeTotal: 0,
      );

      expect(
        models.models.map((model) => model.type).toSet(),
        FinancialIntelligenceModelType.values.toSet(),
      );
    });
  });
}

FinancialBehaviorCompatibilityOutput _outputFor({
  required FinancialModelPeriod period,
  required List<Operation> operations,
  required List<Category> categories,
}) {
  const factsService = FinancialBehaviorFactsService();
  const totalsService = FinancialBehaviorTotalsService();
  final snapshot = factsService.buildSnapshot(
    operations: operations,
    categories: categories,
  );

  return totalsService.outputFor(snapshot: snapshot, period: period);
}

Category _category({
  required String id,
  required CategoryStableKey? stableKey,
  String nameKey = 'categoryUnknownLegacy',
}) {
  final now = DateTime.utc(2026);

  return Category(
    id: id,
    type: CategoryType.expense,
    uiGroup: CategoryUiGroup.dailyLife,
    analyticsGroup: CategoryAnalyticsGroup.flexibleExpenses,
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
  DateTime? occurredAt,
}) {
  final now = occurredAt ?? DateTime.utc(2026, 7, 10);

  return Operation(
    id: id,
    userId: 'user-id',
    type: OperationType.expense,
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
