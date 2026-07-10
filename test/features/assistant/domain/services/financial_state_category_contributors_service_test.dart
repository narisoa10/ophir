import 'package:flutter_test/flutter_test.dart';
import 'package:ophir/features/assistant/domain/entities/financial_behavior_fact.dart';
import 'package:ophir/features/assistant/domain/entities/financial_behavior_fact_kind.dart';
import 'package:ophir/features/assistant/domain/entities/financial_behavior_facts_snapshot.dart';
import 'package:ophir/features/assistant/domain/entities/financial_model_limitation.dart';
import 'package:ophir/features/assistant/domain/entities/financial_model_period.dart';
import 'package:ophir/features/assistant/domain/entities/financial_state.dart';
import 'package:ophir/features/assistant/domain/entities/financial_state_confidence.dart';
import 'package:ophir/features/assistant/domain/entities/financial_state_contributor_strategy.dart';
import 'package:ophir/features/assistant/domain/entities/financial_state_type.dart';
import 'package:ophir/features/assistant/domain/services/financial_state_category_contributors_service.dart';
import 'package:ophir/features/categories/domain/enums/category_financial_distribution_role.dart';
import 'package:ophir/features/categories/domain/enums/category_stable_key.dart';
import 'package:ophir/features/categories/domain/enums/spending_pattern.dart';
import 'package:ophir/features/operations/domain/enums/operation_type.dart';

void main() {
  const service = FinancialStateCategoryContributorsService();

  group('FinancialStateCategoryContributorsService', () {
    test(
      'deficit uses closeDeficit and required amount equals negative net',
      () {
        final snapshot = service.build(
          financialState: _state(type: FinancialStateType.deficit, net: -125),
          behaviorFacts: _snapshot(),
        );

        expect(
          snapshot.strategy,
          FinancialStateContributorStrategy.closeDeficit,
        );
        expect(snapshot.requiredAmount, 125);
      },
    );

    test('fragileBalance uses buildSafetyMargin and required margin gap', () {
      final snapshot = service.build(
        financialState: _state(
          type: FinancialStateType.fragileBalance,
          income: 1000,
          net: 40,
        ),
        behaviorFacts: _snapshot(),
      );

      expect(
        snapshot.strategy,
        FinancialStateContributorStrategy.buildSafetyMargin,
      );
      expect(snapshot.requiredAmount, 60);
    });

    test('stable has no required amount and complete empty coverage', () {
      final snapshot = service.build(
        financialState: _state(type: FinancialStateType.stable),
        behaviorFacts: _snapshot(facts: [_fact(amount: 100)]),
      );

      expect(
        snapshot.strategy,
        FinancialStateContributorStrategy.preserveStability,
      );
      expect(snapshot.requiredAmount, 0);
      expect(snapshot.contributors, isEmpty);
      expect(snapshot.isCoverageComplete, isTrue);
    });

    test('growth uses supportGrowth', () {
      final snapshot = service.build(
        financialState: _state(type: FinancialStateType.growth),
        behaviorFacts: _snapshot(),
      );

      expect(
        snapshot.strategy,
        FinancialStateContributorStrategy.supportGrowth,
      );
    });

    test('strongPosition uses protectStrongPosition', () {
      final snapshot = service.build(
        financialState: _state(type: FinancialStateType.strongPosition),
        behaviorFacts: _snapshot(),
      );

      expect(
        snapshot.strategy,
        FinancialStateContributorStrategy.protectStrongPosition,
      );
    });

    test('sorts wants before flexibleExpenses before mandatoryExpenses', () {
      final snapshot = service.build(
        financialState: _state(type: FinancialStateType.deficit, net: -300),
        behaviorFacts: _snapshot(
          facts: [
            _fact(
              categoryId: 'mandatory',
              amount: 100,
              distributionRole:
                  CategoryFinancialDistributionRole.mandatoryExpenses,
            ),
            _fact(
              categoryId: 'flexible',
              amount: 100,
              distributionRole:
                  CategoryFinancialDistributionRole.flexibleExpenses,
            ),
            _fact(
              categoryId: 'wants',
              amount: 100,
              distributionRole: CategoryFinancialDistributionRole.wants,
            ),
          ],
        ),
      );

      expect(
        snapshot.contributors.map(
          (contributor) => contributor.distributionRole,
        ),
        [
          CategoryFinancialDistributionRole.wants,
          CategoryFinancialDistributionRole.flexibleExpenses,
          CategoryFinancialDistributionRole.mandatoryExpenses,
        ],
      );
    });

    test('sorts by spending pattern priority', () {
      final snapshot = service.build(
        financialState: _state(type: FinancialStateType.deficit, net: -400),
        behaviorFacts: _snapshot(
          facts: [
            _fact(
              categoryId: 'periodic',
              stableKey: CategoryStableKey.expenseHousingPropertyTax,
              amount: 100,
            ),
            _fact(
              categoryId: 'recurring',
              stableKey: CategoryStableKey
                  .expenseEntertainmentLifestyleStreamingSubscriptions,
              amount: 100,
            ),
            _fact(
              categoryId: 'one-off',
              stableKey: CategoryStableKey.expenseEntertainmentLifestyleTravel,
              amount: 100,
            ),
            _fact(
              categoryId: 'variable',
              stableKey: CategoryStableKey.expenseFoodRestaurant,
              amount: 100,
            ),
          ],
        ),
      );

      expect(
        snapshot.contributors.map((contributor) => contributor.spendingPattern),
        [
          SpendingPattern.usuallyVariable,
          SpendingPattern.usuallyOneOff,
          SpendingPattern.usuallyRecurring,
          SpendingPattern.periodic,
        ],
      );
    });

    test('excludes unsupported facts and context-dependent categories', () {
      final snapshot = service.build(
        financialState: _state(type: FinancialStateType.deficit, net: -10),
        behaviorFacts: _snapshot(
          facts: [
            _fact(categoryId: 'allowed', amount: 10),
            _fact(
              categoryId: 'asset-building',
              kind: FinancialBehaviorFactKind.assetBuilding,
              stableKey: CategoryStableKey.expenseFinanceSavings,
              amount: 100,
            ),
            _fact(
              categoryId: 'debt',
              kind: FinancialBehaviorFactKind.debtReduction,
              stableKey: CategoryStableKey.expenseFinanceDebtRepayment,
              amount: 100,
            ),
            _fact(
              categoryId: 'cash',
              kind: FinancialBehaviorFactKind.cashMovement,
              stableKey: CategoryStableKey.expenseOtherCashWithdrawal,
              amount: 100,
            ),
            _fact(
              categoryId: 'adjustment',
              kind: FinancialBehaviorFactKind.dataAdjustment,
              stableKey: CategoryStableKey.expenseOtherAdjustment,
              amount: 100,
            ),
            _fact(
              categoryId: 'asset-building-role',
              distributionRole: CategoryFinancialDistributionRole.assetBuilding,
              amount: 100,
            ),
            _fact(
              categoryId: 'debt-role',
              distributionRole: CategoryFinancialDistributionRole.debtReduction,
              amount: 100,
            ),
            _fact(
              categoryId: 'cash-role',
              distributionRole: CategoryFinancialDistributionRole.cashMovement,
              amount: 100,
            ),
            _fact(
              categoryId: 'adjustment-role',
              distributionRole:
                  CategoryFinancialDistributionRole.dataAdjustment,
              amount: 100,
            ),
            _fact(
              categoryId: 'context-role',
              distributionRole:
                  CategoryFinancialDistributionRole.contextDependent,
              amount: 100,
            ),
            _fact(
              categoryId: 'unresolved',
              kind: FinancialBehaviorFactKind.unresolved,
              amount: 100,
            ),
            _fact(
              categoryId: 'requires-context',
              requiresTransactionContext: true,
              amount: 100,
            ),
            _fact(
              categoryId: 'requires-evidence',
              stableKey: CategoryStableKey.expenseFinanceCurrencyExchange,
              distributionRole:
                  CategoryFinancialDistributionRole.flexibleExpenses,
              amount: 100,
            ),
          ],
        ),
      );

      expect(
        snapshot.contributors.map((contributor) => contributor.categoryId),
        ['allowed'],
      );
      expect(snapshot.coveredAmount, 10);
    });

    test('selects minimal sufficient contributors and sums covered amount', () {
      final snapshot = service.build(
        financialState: _state(type: FinancialStateType.deficit, net: -120),
        behaviorFacts: _snapshot(
          facts: [
            _fact(categoryId: 'wants-large', amount: 100),
            _fact(
              categoryId: 'flexible-small',
              amount: 30,
              distributionRole:
                  CategoryFinancialDistributionRole.flexibleExpenses,
            ),
            _fact(
              categoryId: 'mandatory-large',
              amount: 100,
              distributionRole:
                  CategoryFinancialDistributionRole.mandatoryExpenses,
            ),
          ],
        ),
      );

      expect(
        snapshot.contributors.map((contributor) => contributor.categoryId),
        ['wants-large', 'flexible-small'],
      );
      expect(snapshot.coveredAmount, 130);
      expect(snapshot.isCoverageComplete, isTrue);
    });

    test('returns all eligible contributors when coverage is insufficient', () {
      final snapshot = service.build(
        financialState: _state(type: FinancialStateType.deficit, net: -300),
        behaviorFacts: _snapshot(
          facts: [
            _fact(categoryId: 'first', amount: 100),
            _fact(categoryId: 'second', amount: 50),
          ],
        ),
      );

      expect(snapshot.contributors, hasLength(2));
      expect(snapshot.coveredAmount, 150);
      expect(snapshot.isCoverageComplete, isFalse);
    });

    test('percentages are null when income or expenses are non-positive', () {
      final snapshot = service.build(
        financialState: _state(
          type: FinancialStateType.deficit,
          income: 0,
          expenses: 0,
          net: -10,
        ),
        behaviorFacts: _snapshot(facts: [_fact(amount: 10)]),
      );

      expect(snapshot.contributors.single.percentOfIncome, isNull);
      expect(snapshot.contributors.single.percentOfExpenses, isNull);
    });

    test('mixed currency or null currency disables contributor coverage', () {
      final nullCurrency = service.build(
        financialState: _state(
          type: FinancialStateType.deficit,
          currencyCode: null,
          net: -100,
        ),
        behaviorFacts: _snapshot(facts: [_fact(amount: 100)]),
      );
      final mixedCurrency = service.build(
        financialState: _state(
          type: FinancialStateType.fragileBalance,
          net: -100,
          limitations: const [FinancialModelLimitation.mixedCurrencies],
        ),
        behaviorFacts: _snapshot(facts: [_fact(amount: 100)]),
      );

      for (final snapshot in [nullCurrency, mixedCurrency]) {
        expect(snapshot.contributors, isEmpty);
        expect(snapshot.coveredAmount, 0);
        expect(snapshot.isCoverageComplete, isFalse);
      }
    });
  });
}

FinancialState _state({
  required FinancialStateType type,
  double income = 1000,
  double expenses = 800,
  double net = 200,
  String? currencyCode = 'CAD',
  List<FinancialModelLimitation> limitations = const [],
}) {
  return FinancialState(
    type: type,
    confidence: FinancialStateConfidence.high,
    period: FinancialModelPeriod(
      start: DateTime.utc(2035, 6),
      end: DateTime.utc(2035, 7),
    ),
    currencyCode: currencyCode,
    income: income,
    expenses: expenses,
    net: net,
    evidenceModelIds: const ['model'],
    limitations: limitations,
  );
}

FinancialBehaviorFactsSnapshot _snapshot({
  List<FinancialBehaviorFact> facts = const [],
}) {
  return FinancialBehaviorFactsSnapshot(facts: facts);
}

FinancialBehaviorFact _fact({
  String operationId = 'operation',
  String? categoryId = 'category',
  CategoryStableKey? stableKey = CategoryStableKey.expenseFoodRestaurant,
  double amount = 1,
  String currencyCode = 'CAD',
  FinancialBehaviorFactKind kind = FinancialBehaviorFactKind.ordinarySpending,
  CategoryFinancialDistributionRole? distributionRole =
      CategoryFinancialDistributionRole.wants,
  bool requiresTransactionContext = false,
}) {
  return FinancialBehaviorFact(
    operationId: operationId,
    operationType: OperationType.expense,
    categoryId: categoryId,
    stableKey: stableKey,
    amount: amount,
    currencyCode: currencyCode,
    occurredAt: DateTime.utc(2035, 6, 10),
    kind: kind,
    distributionRole: distributionRole,
    requiresTransactionContext: requiresTransactionContext,
  );
}
