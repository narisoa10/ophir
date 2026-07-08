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

final class BurnRateModelService {
  const BurnRateModelService({
    this.resultBuilder = const FinancialModelResultBuilder(),
  });

  final FinancialModelResultBuilder resultBuilder;

  FinancialModelResult simpleBurnRate({
    required FinancialFactsSnapshot snapshot,
    required FinancialModelPeriod period,
    required DateTime calculatedAt,
  }) {
    final expenseFacts = snapshot.facts
        .where(
          (fact) =>
              fact.type == FinancialFactType.expenseOperation &&
              fact.occurredAt != null &&
              period.contains(fact.occurredAt!),
        )
        .toList();
    final currencies = _currencies(expenseFacts);

    if (expenseFacts.isEmpty) {
      return resultBuilder.result(
        snapshot: snapshot,
        period: period,
        calculatedAt: calculatedAt,
        type: FinancialModelType.simpleBurnRate,
        status: FinancialModelStatus.insufficientData,
        value: null,
        currencyCode: null,
        evidenceFacts: expenseFacts,
        limitations: const [FinancialModelLimitation.noMatchingFacts],
        modelConfidence: FinancialModelConfidence.none,
      );
    }
    if (currencies.length > 1) {
      return resultBuilder.result(
        snapshot: snapshot,
        period: period,
        calculatedAt: calculatedAt,
        type: FinancialModelType.simpleBurnRate,
        status: FinancialModelStatus.unavailable,
        value: null,
        currencyCode: null,
        evidenceFacts: expenseFacts,
        limitations: const [FinancialModelLimitation.mixedCurrencies],
        modelConfidence: FinancialModelConfidence.none,
      );
    }

    final monthCount = period.dayCount / 30.4375;
    final burnRate = _sum(expenseFacts) / monthCount;
    return resultBuilder.result(
      snapshot: snapshot,
      period: period,
      calculatedAt: calculatedAt,
      type: FinancialModelType.simpleBurnRate,
      status: FinancialModelStatus.calculated,
      value: burnRate,
      currencyCode: _singleCurrency(currencies),
      evidenceFacts: expenseFacts,
      limitations: burnRate == 0
          ? const [FinancialModelLimitation.zeroExpense]
          : const [],
      modelConfidence: FinancialModelConfidence.medium,
      assumptions: const [
        'Simple burn rate annualizes the selected period to an average month.',
      ],
    );
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
