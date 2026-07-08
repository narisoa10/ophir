import '../entities/financial_fact.dart';
import '../entities/financial_fact_type.dart';
import '../entities/financial_model_confidence.dart';
import '../entities/financial_model_limitation.dart';
import '../entities/financial_model_period.dart';
import '../entities/financial_model_result.dart';
import '../entities/financial_model_status.dart';
import '../entities/financial_model_type.dart';
import '../entities/financial_facts_snapshot.dart';
import 'financial_model_result_builder.dart';

final class ExpenseRatioModelService {
  const ExpenseRatioModelService({
    this.resultBuilder = const FinancialModelResultBuilder(),
  });

  final FinancialModelResultBuilder resultBuilder;

  FinancialModelResult expenseToIncomeRatio({
    required FinancialFactsSnapshot snapshot,
    required FinancialModelPeriod period,
    required DateTime calculatedAt,
  }) {
    final income = _operationFacts(
      snapshot,
      period,
      FinancialFactType.incomeOperation,
    );
    final expenses = _operationFacts(
      snapshot,
      period,
      FinancialFactType.expenseOperation,
    );
    return _ratio(
      snapshot: snapshot,
      period: period,
      calculatedAt: calculatedAt,
      type: FinancialModelType.expenseToIncomeRatio,
      numeratorFacts: expenses,
      denominatorFacts: income,
      denominator: _sum(income),
      numerator: _sum(expenses),
      zeroDenominatorLimitation: FinancialModelLimitation.zeroIncome,
    );
  }

  FinancialModelResult expenseAnalyticsGroupTotals({
    required FinancialFactsSnapshot snapshot,
    required FinancialModelPeriod period,
    required DateTime calculatedAt,
  }) {
    final expenseFacts = _operationFacts(
      snapshot,
      period,
      FinancialFactType.expenseOperation,
    );
    final analyticsFacts = _analyticsFactsFor(snapshot, expenseFacts);
    final currencies = _currencies(expenseFacts);

    if (expenseFacts.isEmpty) {
      return _insufficient(
        snapshot: snapshot,
        period: period,
        calculatedAt: calculatedAt,
        type: FinancialModelType.expenseAnalyticsGroupTotals,
        facts: expenseFacts,
      );
    }
    if (currencies.length > 1) {
      return _mixedCurrency(
        snapshot: snapshot,
        period: period,
        calculatedAt: calculatedAt,
        type: FinancialModelType.expenseAnalyticsGroupTotals,
        facts: expenseFacts,
      );
    }

    final byOperation = {
      for (final fact in expenseFacts) fact.operationId: fact,
    };
    final totals = <String, double>{};
    final breakdown = <FinancialModelResult>[];
    for (final analyticsFact in analyticsFacts) {
      final operationFact = byOperation[analyticsFact.operationId];
      final group = analyticsFact.analyticsGroup?.name;
      if (operationFact == null || group == null) {
        continue;
      }
      totals[group] = (totals[group] ?? 0) + (operationFact.amount ?? 0);
    }
    for (final entry in totals.entries) {
      breakdown.add(
        resultBuilder.result(
          snapshot: snapshot,
          period: period,
          calculatedAt: calculatedAt,
          type: FinancialModelType.expenseAnalyticsGroupTotals,
          status: FinancialModelStatus.calculated,
          value: entry.value,
          currencyCode: _singleCurrency(currencies),
          evidenceFacts: analyticsFacts
              .where((fact) => fact.analyticsGroup?.name == entry.key)
              .toList(),
          limitations: const [],
          modelConfidence: FinancialModelConfidence.high,
          assumptions: ['analyticsGroup:${entry.key}'],
        ),
      );
    }

    return resultBuilder.result(
      snapshot: snapshot,
      period: period,
      calculatedAt: calculatedAt,
      type: FinancialModelType.expenseAnalyticsGroupTotals,
      status: FinancialModelStatus.calculated,
      value: _sum(expenseFacts),
      currencyCode: _singleCurrency(currencies),
      evidenceFacts: [...expenseFacts, ...analyticsFacts],
      limitations: analyticsFacts.length < expenseFacts.length
          ? const [FinancialModelLimitation.missingCategories]
          : const [],
      modelConfidence: analyticsFacts.length < expenseFacts.length
          ? FinancialModelConfidence.medium
          : FinancialModelConfidence.high,
      breakdown: breakdown,
    );
  }

  FinancialModelResult essentialRatio({
    required FinancialFactsSnapshot snapshot,
    required FinancialModelPeriod period,
    required DateTime calculatedAt,
  }) {
    return _analyticsGroupRatio(
      snapshot: snapshot,
      period: period,
      calculatedAt: calculatedAt,
      type: FinancialModelType.essentialRatio,
      groupName: 'essentialExpenses',
    );
  }

  FinancialModelResult flexibleRatio({
    required FinancialFactsSnapshot snapshot,
    required FinancialModelPeriod period,
    required DateTime calculatedAt,
  }) {
    return _analyticsGroupRatio(
      snapshot: snapshot,
      period: period,
      calculatedAt: calculatedAt,
      type: FinancialModelType.flexibleRatio,
      groupName: 'flexibleExpenses',
    );
  }

  FinancialModelResult lifestyleRatio({
    required FinancialFactsSnapshot snapshot,
    required FinancialModelPeriod period,
    required DateTime calculatedAt,
  }) {
    return _analyticsGroupRatio(
      snapshot: snapshot,
      period: period,
      calculatedAt: calculatedAt,
      type: FinancialModelType.lifestyleRatio,
      groupName: 'lifestyleEntertainment',
    );
  }

  FinancialModelResult _analyticsGroupRatio({
    required FinancialFactsSnapshot snapshot,
    required FinancialModelPeriod period,
    required DateTime calculatedAt,
    required FinancialModelType type,
    required String groupName,
  }) {
    final expenseFacts = _operationFacts(
      snapshot,
      period,
      FinancialFactType.expenseOperation,
    );
    final analyticsFacts = _analyticsFactsFor(snapshot, expenseFacts);
    final operationById = {
      for (final fact in expenseFacts) fact.operationId: fact,
    };
    final groupFacts = analyticsFacts
        .where((fact) => fact.analyticsGroup?.name == groupName)
        .toList();
    final numerator = groupFacts.fold<double>(
      0,
      (sum, fact) => sum + (operationById[fact.operationId]?.amount ?? 0),
    );

    return _ratio(
      snapshot: snapshot,
      period: period,
      calculatedAt: calculatedAt,
      type: type,
      numeratorFacts: groupFacts,
      denominatorFacts: expenseFacts,
      numerator: numerator,
      denominator: _sum(expenseFacts),
      zeroDenominatorLimitation: FinancialModelLimitation.zeroExpense,
      additionalLimitations: analyticsFacts.length < expenseFacts.length
          ? const [FinancialModelLimitation.missingCategories]
          : const [],
    );
  }

  FinancialModelResult _ratio({
    required FinancialFactsSnapshot snapshot,
    required FinancialModelPeriod period,
    required DateTime calculatedAt,
    required FinancialModelType type,
    required List<FinancialFact> numeratorFacts,
    required List<FinancialFact> denominatorFacts,
    required double numerator,
    required double denominator,
    required FinancialModelLimitation zeroDenominatorLimitation,
    List<FinancialModelLimitation> additionalLimitations = const [],
  }) {
    final facts = {...numeratorFacts, ...denominatorFacts}.toList();
    final currencies = _currencies(facts);
    if (facts.isEmpty) {
      return _insufficient(
        snapshot: snapshot,
        period: period,
        calculatedAt: calculatedAt,
        type: type,
        facts: facts,
      );
    }
    if (currencies.length > 1) {
      return _mixedCurrency(
        snapshot: snapshot,
        period: period,
        calculatedAt: calculatedAt,
        type: type,
        facts: denominatorFacts,
      );
    }
    if (denominatorFacts.isEmpty || denominator == 0) {
      return resultBuilder.result(
        snapshot: snapshot,
        period: period,
        calculatedAt: calculatedAt,
        type: type,
        status: FinancialModelStatus.insufficientData,
        value: null,
        currencyCode: _singleCurrency(currencies),
        evidenceFacts: facts,
        limitations: <FinancialModelLimitation>[
          zeroDenominatorLimitation,
          ...additionalLimitations,
        ],
        modelConfidence: FinancialModelConfidence.none,
      );
    }

    return resultBuilder.result(
      snapshot: snapshot,
      period: period,
      calculatedAt: calculatedAt,
      type: type,
      status: FinancialModelStatus.calculated,
      value: numerator / denominator,
      currencyCode: null,
      evidenceFacts: facts,
      limitations: additionalLimitations,
      modelConfidence: additionalLimitations.isEmpty
          ? FinancialModelConfidence.high
          : FinancialModelConfidence.medium,
    );
  }

  FinancialModelResult _insufficient({
    required FinancialFactsSnapshot snapshot,
    required FinancialModelPeriod period,
    required DateTime calculatedAt,
    required FinancialModelType type,
    required List<FinancialFact> facts,
  }) {
    return resultBuilder.result(
      snapshot: snapshot,
      period: period,
      calculatedAt: calculatedAt,
      type: type,
      status: FinancialModelStatus.insufficientData,
      value: null,
      currencyCode: null,
      evidenceFacts: facts,
      limitations: const [FinancialModelLimitation.noMatchingFacts],
      modelConfidence: FinancialModelConfidence.none,
    );
  }

  FinancialModelResult _mixedCurrency({
    required FinancialFactsSnapshot snapshot,
    required FinancialModelPeriod period,
    required DateTime calculatedAt,
    required FinancialModelType type,
    required List<FinancialFact> facts,
  }) {
    return resultBuilder.result(
      snapshot: snapshot,
      period: period,
      calculatedAt: calculatedAt,
      type: type,
      status: FinancialModelStatus.unavailable,
      value: null,
      currencyCode: null,
      evidenceFacts: facts,
      limitations: const [FinancialModelLimitation.mixedCurrencies],
      modelConfidence: FinancialModelConfidence.none,
    );
  }

  List<FinancialFact> _operationFacts(
    FinancialFactsSnapshot snapshot,
    FinancialModelPeriod period,
    FinancialFactType type,
  ) {
    return snapshot.facts
        .where(
          (fact) =>
              fact.type == type &&
              fact.occurredAt != null &&
              period.contains(fact.occurredAt!),
        )
        .toList();
  }

  List<FinancialFact> _analyticsFactsFor(
    FinancialFactsSnapshot snapshot,
    List<FinancialFact> operationFacts,
  ) {
    final operationIds = operationFacts.map((fact) => fact.operationId).toSet();
    return snapshot.facts
        .where(
          (fact) =>
              fact.type == FinancialFactType.analyticsGroup &&
              operationIds.contains(fact.operationId),
        )
        .toList();
  }

  double _sum(List<FinancialFact> facts) {
    return facts.fold<double>(0, (sum, fact) => sum + (fact.amount ?? 0));
  }

  Set<String> _currencies(List<FinancialFact> facts) {
    return {
      for (final fact in facts)
        if (fact.currencyCode != null) fact.currencyCode!,
    };
  }

  String? _singleCurrency(Set<String> currencies) {
    return currencies.length == 1 ? currencies.first : null;
  }
}
