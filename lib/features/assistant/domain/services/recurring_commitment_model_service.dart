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

final class RecurringCommitmentModelService {
  const RecurringCommitmentModelService({
    this.resultBuilder = const FinancialModelResultBuilder(),
  });

  final FinancialModelResultBuilder resultBuilder;

  FinancialModelResult recurringCommitments({
    required FinancialFactsSnapshot snapshot,
    required FinancialModelPeriod period,
    required DateTime calculatedAt,
  }) {
    return _recurringMonthlyTotal(
      snapshot: snapshot,
      period: period,
      calculatedAt: calculatedAt,
      type: FinancialModelType.recurringCommitments,
    );
  }

  FinancialModelResult monthlyFixedCostEstimate({
    required FinancialFactsSnapshot snapshot,
    required FinancialModelPeriod period,
    required DateTime calculatedAt,
  }) {
    return _recurringMonthlyTotal(
      snapshot: snapshot,
      period: period,
      calculatedAt: calculatedAt,
      type: FinancialModelType.monthlyFixedCostEstimate,
    );
  }

  FinancialModelResult subscriptionLoadEstimate({
    required FinancialFactsSnapshot snapshot,
    required FinancialModelPeriod period,
    required DateTime calculatedAt,
  }) {
    final facts = _recurringExpenseFacts(snapshot, period);
    return resultBuilder.result(
      snapshot: snapshot,
      period: period,
      calculatedAt: calculatedAt,
      type: FinancialModelType.subscriptionLoadEstimate,
      status: FinancialModelStatus.unavailable,
      value: null,
      currencyCode: null,
      evidenceFacts: facts,
      limitations: const [FinancialModelLimitation.unknownRecurringPattern],
      modelConfidence: FinancialModelConfidence.none,
      assumptions: const [
        'Current facts do not classify recurring operations as subscriptions.',
      ],
    );
  }

  FinancialModelResult variableCostEstimate({
    required FinancialFactsSnapshot snapshot,
    required FinancialModelPeriod period,
    required DateTime calculatedAt,
  }) {
    final expenseFacts = _operationFacts(
      snapshot,
      period,
      FinancialFactType.expenseOperation,
    );
    final recurringOperationIds = _recurringFacts(
      snapshot,
      period,
    ).map((fact) => fact.operationId).toSet();
    final variableFacts = expenseFacts
        .where((fact) => !recurringOperationIds.contains(fact.operationId))
        .toList();
    final currencies = _currencies(expenseFacts);

    if (expenseFacts.isEmpty) {
      return _insufficient(
        snapshot: snapshot,
        period: period,
        calculatedAt: calculatedAt,
        type: FinancialModelType.variableCostEstimate,
        facts: expenseFacts,
      );
    }
    if (currencies.length > 1) {
      return _mixedCurrency(
        snapshot: snapshot,
        period: period,
        calculatedAt: calculatedAt,
        type: FinancialModelType.variableCostEstimate,
        facts: expenseFacts,
      );
    }

    return resultBuilder.result(
      snapshot: snapshot,
      period: period,
      calculatedAt: calculatedAt,
      type: FinancialModelType.variableCostEstimate,
      status: FinancialModelStatus.calculated,
      value: _sum(variableFacts),
      currencyCode: _singleCurrency(currencies),
      evidenceFacts: variableFacts,
      limitations: variableFacts.isEmpty
          ? const [FinancialModelLimitation.zeroExpense]
          : const [],
      modelConfidence: FinancialModelConfidence.medium,
      assumptions: const [
        'Variable cost is period expense not marked by recurring facts.',
      ],
    );
  }

  FinancialModelResult _recurringMonthlyTotal({
    required FinancialFactsSnapshot snapshot,
    required FinancialModelPeriod period,
    required DateTime calculatedAt,
    required FinancialModelType type,
  }) {
    final facts = _recurringExpenseFacts(snapshot, period);
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
        facts: facts,
      );
    }

    var hasUnknownPattern = false;
    final monthlyTotal = facts.fold<double>(0, (sum, fact) {
      final factor = _monthlyFactor(fact.recurrence?.name);
      if (factor == null) {
        hasUnknownPattern = true;
        return sum;
      }
      return sum + ((fact.amount ?? 0) * factor);
    });

    if (hasUnknownPattern) {
      return resultBuilder.result(
        snapshot: snapshot,
        period: period,
        calculatedAt: calculatedAt,
        type: type,
        status: FinancialModelStatus.unavailable,
        value: null,
        currencyCode: _singleCurrency(currencies),
        evidenceFacts: facts,
        limitations: const [FinancialModelLimitation.unknownRecurringPattern],
        modelConfidence: FinancialModelConfidence.none,
      );
    }

    return resultBuilder.result(
      snapshot: snapshot,
      period: period,
      calculatedAt: calculatedAt,
      type: type,
      status: FinancialModelStatus.calculated,
      value: monthlyTotal,
      currencyCode: _singleCurrency(currencies),
      evidenceFacts: facts,
      limitations: const [],
      modelConfidence: FinancialModelConfidence.medium,
      assumptions: const [
        'Recurring operations are normalized to an average monthly amount.',
      ],
    );
  }

  double? _monthlyFactor(String? recurrenceName) {
    return switch (recurrenceName) {
      'daily' => 30,
      'weekly' => 52 / 12,
      'biweekly' => 26 / 12,
      'monthly' => 1,
      'yearly' => 1 / 12,
      _ => null,
    };
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

  List<FinancialFact> _recurringFacts(
    FinancialFactsSnapshot snapshot,
    FinancialModelPeriod period,
  ) {
    return snapshot.facts
        .where(
          (fact) =>
              fact.type == FinancialFactType.recurringOperation &&
              fact.occurredAt != null &&
              period.contains(fact.occurredAt!),
        )
        .toList();
  }

  List<FinancialFact> _recurringExpenseFacts(
    FinancialFactsSnapshot snapshot,
    FinancialModelPeriod period,
  ) {
    final expenseOperationIds = _operationFacts(
      snapshot,
      period,
      FinancialFactType.expenseOperation,
    ).map((fact) => fact.operationId).toSet();

    return _recurringFacts(
      snapshot,
      period,
    ).where((fact) => expenseOperationIds.contains(fact.operationId)).toList();
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
