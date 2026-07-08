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

final class CashFlowModelService {
  const CashFlowModelService({
    this.resultBuilder = const FinancialModelResultBuilder(),
  });

  final FinancialModelResultBuilder resultBuilder;

  FinancialModelResult incomeTotal({
    required FinancialFactsSnapshot snapshot,
    required FinancialModelPeriod period,
    required DateTime calculatedAt,
  }) {
    return _total(
      snapshot: snapshot,
      period: period,
      calculatedAt: calculatedAt,
      type: FinancialModelType.incomeTotal,
      factType: FinancialFactType.incomeOperation,
      zeroLimitation: FinancialModelLimitation.zeroIncome,
    );
  }

  FinancialModelResult expenseTotal({
    required FinancialFactsSnapshot snapshot,
    required FinancialModelPeriod period,
    required DateTime calculatedAt,
  }) {
    return _total(
      snapshot: snapshot,
      period: period,
      calculatedAt: calculatedAt,
      type: FinancialModelType.expenseTotal,
      factType: FinancialFactType.expenseOperation,
      zeroLimitation: FinancialModelLimitation.zeroExpense,
    );
  }

  FinancialModelResult netCashFlow({
    required FinancialFactsSnapshot snapshot,
    required FinancialModelPeriod period,
    required DateTime calculatedAt,
  }) {
    final income = incomeTotal(
      snapshot: snapshot,
      period: period,
      calculatedAt: calculatedAt,
    );
    final expenses = expenseTotal(
      snapshot: snapshot,
      period: period,
      calculatedAt: calculatedAt,
    );
    final facts = _periodOperationFacts(snapshot, period);
    final currencies = _currencies(facts);
    final limitations = {
      ...income.limitations,
      ...expenses.limitations,
    }.toList();

    if (facts.isEmpty) {
      return _insufficient(
        snapshot: snapshot,
        period: period,
        calculatedAt: calculatedAt,
        type: FinancialModelType.netCashFlow,
        facts: facts,
      );
    }
    if (currencies.length > 1) {
      return _mixedCurrency(
        snapshot: snapshot,
        period: period,
        calculatedAt: calculatedAt,
        type: FinancialModelType.netCashFlow,
        facts: facts,
      );
    }

    return resultBuilder.result(
      snapshot: snapshot,
      period: period,
      calculatedAt: calculatedAt,
      type: FinancialModelType.netCashFlow,
      status: FinancialModelStatus.calculated,
      value: (income.value ?? 0) - (expenses.value ?? 0),
      currencyCode: _singleCurrency(currencies),
      evidenceFacts: facts,
      limitations: limitations,
      modelConfidence: FinancialModelConfidence.high,
    );
  }

  FinancialModelResult cashFlowSummary({
    required FinancialFactsSnapshot snapshot,
    required FinancialModelPeriod period,
    required DateTime calculatedAt,
  }) {
    final income = incomeTotal(
      snapshot: snapshot,
      period: period,
      calculatedAt: calculatedAt,
    );
    final expenses = expenseTotal(
      snapshot: snapshot,
      period: period,
      calculatedAt: calculatedAt,
    );
    final net = netCashFlow(
      snapshot: snapshot,
      period: period,
      calculatedAt: calculatedAt,
    );
    final facts = _periodOperationFacts(snapshot, period);
    final currencies = _currencies(facts);

    if (facts.isEmpty) {
      return _insufficient(
        snapshot: snapshot,
        period: period,
        calculatedAt: calculatedAt,
        type: FinancialModelType.cashFlowSummary,
        facts: facts,
      );
    }
    if (currencies.length > 1) {
      return _mixedCurrency(
        snapshot: snapshot,
        period: period,
        calculatedAt: calculatedAt,
        type: FinancialModelType.cashFlowSummary,
        facts: facts,
      );
    }

    return resultBuilder.result(
      snapshot: snapshot,
      period: period,
      calculatedAt: calculatedAt,
      type: FinancialModelType.cashFlowSummary,
      status: FinancialModelStatus.calculated,
      value: net.value,
      currencyCode: _singleCurrency(currencies),
      evidenceFacts: facts,
      limitations: <FinancialModelLimitation>{
        ...income.limitations,
        ...expenses.limitations,
        ...net.limitations,
      }.toList(),
      modelConfidence: FinancialModelConfidence.high,
      breakdown: [income, expenses, net],
    );
  }

  FinancialModelResult _total({
    required FinancialFactsSnapshot snapshot,
    required FinancialModelPeriod period,
    required DateTime calculatedAt,
    required FinancialModelType type,
    required FinancialFactType factType,
    required FinancialModelLimitation zeroLimitation,
  }) {
    final periodFacts = _periodOperationFacts(snapshot, period);
    final facts = periodFacts.where((fact) => fact.type == factType).toList();
    final currencies = _currencies(periodFacts);

    if (periodFacts.isEmpty) {
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
        facts: periodFacts,
      );
    }

    final total = facts.fold<double>(
      0,
      (sum, fact) => sum + (fact.amount ?? 0),
    );
    return resultBuilder.result(
      snapshot: snapshot,
      period: period,
      calculatedAt: calculatedAt,
      type: type,
      status: FinancialModelStatus.calculated,
      value: total,
      currencyCode: _singleCurrency(currencies),
      evidenceFacts: facts.isEmpty ? periodFacts : facts,
      limitations: total == 0 ? [zeroLimitation] : const [],
      modelConfidence: FinancialModelConfidence.high,
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

  List<FinancialFact> _periodOperationFacts(
    FinancialFactsSnapshot snapshot,
    FinancialModelPeriod period,
  ) {
    return snapshot.facts
        .where(
          (fact) =>
              (fact.type == FinancialFactType.incomeOperation ||
                  fact.type == FinancialFactType.expenseOperation) &&
              fact.occurredAt != null &&
              period.contains(fact.occurredAt!),
        )
        .toList();
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
