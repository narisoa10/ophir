import 'package:flutter_test/flutter_test.dart';
import 'package:ophir/features/assistant/domain/entities/financial_fact.dart';
import 'package:ophir/features/assistant/domain/entities/financial_fact_confidence.dart';
import 'package:ophir/features/assistant/domain/entities/financial_fact_data_gap.dart';
import 'package:ophir/features/assistant/domain/entities/financial_fact_data_gap_type.dart';
import 'package:ophir/features/assistant/domain/entities/financial_fact_source.dart';
import 'package:ophir/features/assistant/domain/entities/financial_fact_type.dart';
import 'package:ophir/features/assistant/domain/entities/financial_model_catalog.dart';
import 'package:ophir/features/assistant/domain/entities/financial_model_confidence.dart';
import 'package:ophir/features/assistant/domain/entities/financial_model_limitation.dart';
import 'package:ophir/features/assistant/domain/entities/financial_model_period.dart';
import 'package:ophir/features/assistant/domain/entities/financial_model_result.dart';
import 'package:ophir/features/assistant/domain/entities/financial_model_status.dart';
import 'package:ophir/features/assistant/domain/entities/financial_model_type.dart';
import 'package:ophir/features/assistant/domain/entities/financial_facts_snapshot.dart';
import 'package:ophir/features/assistant/domain/services/financial_models_service.dart';
import 'package:ophir/features/categories/domain/enums/category_analytics_group.dart';
import 'package:ophir/features/operations/domain/enums/operation_recurrence.dart';
import 'package:ophir/features/operations/domain/enums/operation_type.dart';

const _service = FinancialModelsService();
final _period = FinancialModelPeriod(
  start: DateTime(2026, 1),
  end: DateTime(2026, 2),
);
final _calculatedAt = DateTime(2026, 2);

void main() {
  group('FinancialModelsService', () {
    test('calculates every registered model explicitly', () {
      final results = _service.calculateAll(
        snapshot: _snapshot([
          _operationFact('income', FinancialFactType.incomeOperation, 3000),
          _operationFact('rent', FinancialFactType.expenseOperation, 1000),
          _analyticsFact(
            'rent',
            CategoryAnalyticsGroup.essentialExpenses,
            amount: 1000,
          ),
          _recurringFact('rent', 1000, OperationRecurrence.monthly),
        ]),
        period: _period,
        calculatedAt: _calculatedAt,
      );

      expect(results, hasLength(FinancialModelCatalog.definitions.length));
      expect(
        results.map((result) => result.modelType),
        containsAll(FinancialModelCatalog.definitions.map((item) => item.type)),
      );
    });

    test('calculates income, expense, net cash flow and summary', () {
      final snapshot = _snapshot([
        _operationFact('income', FinancialFactType.incomeOperation, 3000),
        _operationFact('food', FinancialFactType.expenseOperation, 500),
        _operationFact('move', FinancialFactType.transferOperation, 900),
      ]);

      final income = _calculate(FinancialModelType.incomeTotal, snapshot);
      final expense = _calculate(FinancialModelType.expenseTotal, snapshot);
      final net = _calculate(FinancialModelType.netCashFlow, snapshot);
      final summary = _calculate(FinancialModelType.cashFlowSummary, snapshot);

      expect(income.value, 3000);
      expect(expense.value, 500);
      expect(net.value, 2500);
      expect(summary.breakdown.map((item) => item.modelType), [
        FinancialModelType.incomeTotal,
        FinancialModelType.expenseTotal,
        FinancialModelType.netCashFlow,
      ]);
    });

    test('filters operation facts by explicit period', () {
      final snapshot = _snapshot([
        _operationFact('inside', FinancialFactType.expenseOperation, 100),
        _operationFact(
          'outside',
          FinancialFactType.expenseOperation,
          900,
          occurredAt: DateTime(2026, 2, 1),
        ),
      ]);

      final expense = _calculate(FinancialModelType.expenseTotal, snapshot);

      expect(expense.value, 100);
      expect(expense.evidence.factIds, ['fact:inside:expenseOperation']);
    });

    test('handles zero income without dividing', () {
      final snapshot = _snapshot([
        _operationFact('expense', FinancialFactType.expenseOperation, 100),
      ]);

      final ratio = _calculate(
        FinancialModelType.expenseToIncomeRatio,
        snapshot,
      );
      final savingsRate = _calculate(FinancialModelType.savingsRate, snapshot);

      expect(ratio.status, FinancialModelStatus.insufficientData);
      expect(ratio.limitations, contains(FinancialModelLimitation.zeroIncome));
      expect(savingsRate.status, FinancialModelStatus.insufficientData);
      expect(
        savingsRate.limitations,
        contains(FinancialModelLimitation.zeroIncome),
      );
    });

    test('handles zero expense deterministically', () {
      final snapshot = _snapshot([
        _operationFact('income', FinancialFactType.incomeOperation, 1000),
      ]);

      final expense = _calculate(FinancialModelType.expenseTotal, snapshot);
      final savingsRate = _calculate(FinancialModelType.savingsRate, snapshot);

      expect(expense.status, FinancialModelStatus.calculated);
      expect(expense.value, 0);
      expect(
        expense.limitations,
        contains(FinancialModelLimitation.zeroExpense),
      );
      expect(savingsRate.value, 1);
      expect(
        savingsRate.limitations,
        contains(FinancialModelLimitation.zeroExpense),
      );
    });

    test('marks mixed currencies unavailable', () {
      final snapshot = _snapshot([
        _operationFact('income', FinancialFactType.incomeOperation, 1000),
        _operationFact(
          'expense',
          FinancialFactType.expenseOperation,
          100,
          currencyCode: 'USD',
        ),
      ]);

      final net = _calculate(FinancialModelType.netCashFlow, snapshot);

      expect(net.status, FinancialModelStatus.unavailable);
      expect(net.value, isNull);
      expect(
        net.limitations,
        contains(FinancialModelLimitation.mixedCurrencies),
      );
      expect(net.dataConfidence, FinancialModelConfidence.none);
    });

    test('calculates analytics group totals and ratios', () {
      final snapshot = _snapshot([
        _operationFact('rent', FinancialFactType.expenseOperation, 900),
        _analyticsFact(
          'rent',
          CategoryAnalyticsGroup.essentialExpenses,
          amount: 900,
        ),
        _operationFact('transport', FinancialFactType.expenseOperation, 200),
        _analyticsFact(
          'transport',
          CategoryAnalyticsGroup.flexibleExpenses,
          amount: 200,
        ),
        _operationFact('fun', FinancialFactType.expenseOperation, 100),
        _analyticsFact(
          'fun',
          CategoryAnalyticsGroup.lifestyleEntertainment,
          amount: 100,
        ),
      ]);

      final totals = _calculate(
        FinancialModelType.expenseAnalyticsGroupTotals,
        snapshot,
      );
      final essential = _calculate(FinancialModelType.essentialRatio, snapshot);
      final lifestyle = _calculate(FinancialModelType.lifestyleRatio, snapshot);
      final flexible = _calculate(FinancialModelType.flexibleRatio, snapshot);

      expect(totals.value, 1200);
      expect(totals.breakdown, hasLength(3));
      expect(
        _analyticsGroupTotal(totals, CategoryAnalyticsGroup.essentialExpenses),
        900,
      );
      expect(
        _analyticsGroupTotal(totals, CategoryAnalyticsGroup.flexibleExpenses),
        200,
      );
      expect(
        _analyticsGroupTotal(
          totals,
          CategoryAnalyticsGroup.lifestyleEntertainment,
        ),
        100,
      );
      expect(essential.value, 0.75);
      expect(flexible.value, closeTo(1 / 6, 0.001));
      expect(lifestyle.value, closeTo(1 / 12, 0.001));
    });

    test('missing analytics group marks group totals as limited', () {
      final snapshot = _snapshot([
        _operationFact('known', FinancialFactType.expenseOperation, 100),
        _analyticsFact(
          'known',
          CategoryAnalyticsGroup.flexibleExpenses,
          amount: 100,
        ),
        _operationFact('missing', FinancialFactType.expenseOperation, 50),
      ]);

      final totals = _calculate(
        FinancialModelType.expenseAnalyticsGroupTotals,
        snapshot,
      );
      final flexible = _calculate(FinancialModelType.flexibleRatio, snapshot);

      expect(totals.value, 150);
      expect(
        totals.limitations,
        contains(FinancialModelLimitation.missingCategories),
      );
      expect(totals.modelConfidence, FinancialModelConfidence.medium);
      expect(flexible.value, closeTo(2 / 3, 0.001));
      expect(
        flexible.limitations,
        contains(FinancialModelLimitation.missingCategories),
      );
      expect(flexible.modelConfidence, FinancialModelConfidence.medium);
    });

    test('calculates recurring commitments and variable cost', () {
      final snapshot = _snapshot([
        _operationFact('rent', FinancialFactType.expenseOperation, 1000),
        _recurringFact('rent', 1000, OperationRecurrence.monthly),
        _operationFact('weekly', FinancialFactType.expenseOperation, 30),
        _recurringFact('weekly', 30, OperationRecurrence.weekly),
        _operationFact('coffee', FinancialFactType.expenseOperation, 50),
      ]);

      final recurring = _calculate(
        FinancialModelType.recurringCommitments,
        snapshot,
      );
      final fixed = _calculate(
        FinancialModelType.monthlyFixedCostEstimate,
        snapshot,
      );
      final variable = _calculate(
        FinancialModelType.variableCostEstimate,
        snapshot,
      );

      expect(recurring.value, closeTo(1130, 0.001));
      expect(fixed.value, closeTo(1130, 0.001));
      expect(variable.value, 50);
      expect(recurring.modelConfidence, FinancialModelConfidence.medium);
    });

    test(
      'recurring commitments include expenses and exclude income/transfer',
      () {
        final snapshot = _snapshot([
          _operationFact('rent', FinancialFactType.expenseOperation, 1000),
          _recurringFact(
            'rent',
            1000,
            OperationRecurrence.monthly,
            operationType: OperationType.expense,
          ),
          _operationFact('salary', FinancialFactType.incomeOperation, 4000),
          _recurringFact(
            'salary',
            4000,
            OperationRecurrence.monthly,
            operationType: OperationType.income,
          ),
          _operationFact('move', FinancialFactType.transferOperation, 700),
          _recurringFact(
            'move',
            700,
            OperationRecurrence.monthly,
            operationType: OperationType.transfer,
          ),
        ]);

        final recurring = _calculate(
          FinancialModelType.recurringCommitments,
          snapshot,
        );
        final fixed = _calculate(
          FinancialModelType.monthlyFixedCostEstimate,
          snapshot,
        );

        expect(recurring.value, 1000);
        expect(fixed.value, 1000);
        expect(recurring.evidence.factIds, ['fact:rent:recurringOperation']);
        expect(fixed.evidence.factIds, ['fact:rent:recurringOperation']);
      },
    );

    test(
      'does not approximate subscription load without subscription facts',
      () {
        final snapshot = _snapshot([
          _recurringFact('rent', 1000, OperationRecurrence.monthly),
        ]);

        final result = _calculate(
          FinancialModelType.subscriptionLoadEstimate,
          snapshot,
        );

        expect(result.status, FinancialModelStatus.unavailable);
        expect(
          result.limitations,
          contains(FinancialModelLimitation.unknownRecurringPattern),
        );
      },
    );

    test('calculates savings rate and simple burn rate', () {
      final snapshot = _snapshot([
        _operationFact('income', FinancialFactType.incomeOperation, 2000),
        _operationFact('expense', FinancialFactType.expenseOperation, 500),
      ]);

      final savings = _calculate(FinancialModelType.savingsRate, snapshot);
      final burn = _calculate(FinancialModelType.simpleBurnRate, snapshot);

      expect(savings.value, 0.75);
      expect(burn.value, closeTo(490.93, 0.01));
    });

    test('scores data quality from gaps, confidence and limitations', () {
      final snapshot = _snapshot(
        [
          _operationFact(
            'expense',
            FinancialFactType.expenseOperation,
            100,
            confidence: FinancialFactConfidence.medium,
          ),
        ],
        gaps: const [
          FinancialFactDataGap(
            type: FinancialFactDataGapType.missingCategory,
            sourceId: 'expense',
            message: 'missing',
          ),
          FinancialFactDataGap(
            type: FinancialFactDataGapType.missingAccountLink,
            sourceId: 'expense',
            message: 'missing',
          ),
        ],
      );

      final quality = _calculate(FinancialModelType.dataQualityScore, snapshot);

      expect(quality.status, FinancialModelStatus.calculated);
      expect(quality.value, lessThan(100));
      expect(
        quality.limitations,
        containsAll([
          FinancialModelLimitation.missingCategories,
          FinancialModelLimitation.missingAccounts,
        ]),
      );
      expect(quality.inputCoverage, quality.value! / 100);
    });

    test('does not expose raw data gap source ids as model evidence', () {
      final snapshot = _snapshot(
        [_operationFact('expense', FinancialFactType.expenseOperation, 100)],
        gaps: const [
          FinancialFactDataGap(
            type: FinancialFactDataGapType.missingCategory,
            sourceId: 'expense',
            message: 'missing',
          ),
        ],
      );

      final result = _calculate(FinancialModelType.expenseTotal, snapshot);
      final quality = _calculate(FinancialModelType.dataQualityScore, snapshot);

      expect(result.evidence.factIds, ['fact:expense:expenseOperation']);
      expect(result.evidence.dataGapSourceIds, isEmpty);
      expect(result.dataConfidence, FinancialModelConfidence.medium);
      expect(result.inputCoverage, lessThan(1));
      expect(
        quality.limitations,
        contains(FinancialModelLimitation.missingCategories),
      );
      expect(quality.inputCoverage, lessThan(1));
    });

    test('preserves evidence references to financial facts only', () {
      final snapshot = _snapshot([
        _operationFact('income', FinancialFactType.incomeOperation, 1000),
      ]);

      final income = _calculate(FinancialModelType.incomeTotal, snapshot);

      expect(income.evidence.factIds, ['fact:income:incomeOperation']);
      expect(income.evidence.dataGapSourceIds, isEmpty);
      expect(income.metadata.calculatedAt, _calculatedAt);
      expect(income.metadata.snapshotVersion, 'facts:1:gaps:0');
    });

    test('separates data confidence and model confidence', () {
      final snapshot = _snapshot(
        [_operationFact('rent', FinancialFactType.expenseOperation, 1000)],
        gaps: const [
          FinancialFactDataGap(
            type: FinancialFactDataGapType.missingCategory,
            sourceId: 'rent',
            message: 'missing',
          ),
        ],
      );

      final result = _calculate(FinancialModelType.expenseTotal, snapshot);

      expect(result.dataConfidence, FinancialModelConfidence.medium);
      expect(result.modelConfidence, FinancialModelConfidence.high);
    });

    test('returns unsupported result for unregistered model type', () {
      final result = _calculate(
        FinancialModelType.unsupported,
        _snapshot(const []),
      );

      expect(result.status, FinancialModelStatus.unsupported);
      expect(result.value, isNull);
      expect(
        result.limitations,
        contains(FinancialModelLimitation.unsupportedModel),
      );
    });
  });
}

double? _analyticsGroupTotal(
  FinancialModelResult result,
  CategoryAnalyticsGroup group,
) {
  for (final item in result.breakdown) {
    if (item.assumptions.contains('analyticsGroup:${group.name}')) {
      return item.value;
    }
  }
  return null;
}

FinancialModelResult _calculate(
  FinancialModelType type,
  FinancialFactsSnapshot snapshot,
) {
  return _service.calculate(
    type: type,
    snapshot: snapshot,
    period: _period,
    calculatedAt: _calculatedAt,
  );
}

FinancialFactsSnapshot _snapshot(
  List<FinancialFact> facts, {
  List<FinancialFactDataGap> gaps = const [],
}) {
  return FinancialFactsSnapshot(
    facts: List.unmodifiable(facts),
    dataGaps: List.unmodifiable(gaps),
  );
}

FinancialFact _operationFact(
  String operationId,
  FinancialFactType type,
  double amount, {
  DateTime? occurredAt,
  String currencyCode = 'CAD',
  FinancialFactConfidence confidence = FinancialFactConfidence.high,
}) {
  return FinancialFact(
    id: 'fact:$operationId:${type.name}',
    type: type,
    source: FinancialFactSource.manualRecorded,
    confidence: confidence,
    operationId: operationId,
    amount: amount,
    currencyCode: currencyCode,
    occurredAt: occurredAt ?? DateTime(2026, 1, 15),
  );
}

FinancialFact _analyticsFact(
  String operationId,
  CategoryAnalyticsGroup analyticsGroup, {
  required double amount,
}) {
  return FinancialFact(
    id: 'fact:$operationId:analyticsGroup',
    type: FinancialFactType.analyticsGroup,
    source: FinancialFactSource.category,
    confidence: FinancialFactConfidence.high,
    operationId: operationId,
    amount: amount,
    currencyCode: 'CAD',
    occurredAt: DateTime(2026, 1, 15),
    analyticsGroup: analyticsGroup,
  );
}

FinancialFact _recurringFact(
  String operationId,
  double amount,
  OperationRecurrence recurrence, {
  OperationType operationType = OperationType.expense,
}) {
  return FinancialFact(
    id: 'fact:$operationId:recurringOperation',
    type: FinancialFactType.recurringOperation,
    source: FinancialFactSource.manualRecorded,
    confidence: FinancialFactConfidence.high,
    operationId: operationId,
    amount: amount,
    currencyCode: 'CAD',
    occurredAt: DateTime(2026, 1, 15),
    recurrence: recurrence,
    operationType: operationType,
  );
}
