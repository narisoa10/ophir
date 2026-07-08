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

final class SavingsRateModelService {
  const SavingsRateModelService({
    this.resultBuilder = const FinancialModelResultBuilder(),
  });

  final FinancialModelResultBuilder resultBuilder;

  FinancialModelResult savingsRate({
    required FinancialFactsSnapshot snapshot,
    required FinancialModelPeriod period,
    required DateTime calculatedAt,
  }) {
    final incomeFacts = _facts(
      snapshot,
      period,
      FinancialFactType.incomeOperation,
    );
    final expenseFacts = _facts(
      snapshot,
      period,
      FinancialFactType.expenseOperation,
    );
    final allFacts = [...incomeFacts, ...expenseFacts];
    final currencies = _currencies(allFacts);

    if (allFacts.isEmpty) {
      return resultBuilder.result(
        snapshot: snapshot,
        period: period,
        calculatedAt: calculatedAt,
        type: FinancialModelType.savingsRate,
        status: FinancialModelStatus.insufficientData,
        value: null,
        currencyCode: null,
        evidenceFacts: allFacts,
        limitations: const [FinancialModelLimitation.noMatchingFacts],
        modelConfidence: FinancialModelConfidence.none,
      );
    }
    if (currencies.length > 1) {
      return resultBuilder.result(
        snapshot: snapshot,
        period: period,
        calculatedAt: calculatedAt,
        type: FinancialModelType.savingsRate,
        status: FinancialModelStatus.unavailable,
        value: null,
        currencyCode: null,
        evidenceFacts: allFacts,
        limitations: const [FinancialModelLimitation.mixedCurrencies],
        modelConfidence: FinancialModelConfidence.none,
      );
    }

    final income = _sum(incomeFacts);
    final expenses = _sum(expenseFacts);
    if (income == 0) {
      return resultBuilder.result(
        snapshot: snapshot,
        period: period,
        calculatedAt: calculatedAt,
        type: FinancialModelType.savingsRate,
        status: FinancialModelStatus.insufficientData,
        value: null,
        currencyCode: _singleCurrency(currencies),
        evidenceFacts: allFacts,
        limitations: const [FinancialModelLimitation.zeroIncome],
        modelConfidence: FinancialModelConfidence.none,
      );
    }

    return resultBuilder.result(
      snapshot: snapshot,
      period: period,
      calculatedAt: calculatedAt,
      type: FinancialModelType.savingsRate,
      status: FinancialModelStatus.calculated,
      value: (income - expenses) / income,
      currencyCode: null,
      evidenceFacts: allFacts,
      limitations: expenses == 0
          ? const [FinancialModelLimitation.zeroExpense]
          : const [],
      modelConfidence: FinancialModelConfidence.high,
    );
  }

  List<FinancialFact> _facts(
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
