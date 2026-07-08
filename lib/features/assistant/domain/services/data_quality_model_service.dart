import '../entities/financial_fact.dart';
import '../entities/financial_fact_confidence.dart';
import '../entities/financial_fact_data_gap_type.dart';
import '../entities/financial_model_confidence.dart';
import '../entities/financial_model_limitation.dart';
import '../entities/financial_model_period.dart';
import '../entities/financial_model_result.dart';
import '../entities/financial_model_status.dart';
import '../entities/financial_model_type.dart';
import '../entities/financial_facts_snapshot.dart';
import 'financial_model_result_builder.dart';

final class DataQualityModelService {
  const DataQualityModelService({
    this.resultBuilder = const FinancialModelResultBuilder(),
  });

  final FinancialModelResultBuilder resultBuilder;

  FinancialModelResult dataQualityScore({
    required FinancialFactsSnapshot snapshot,
    required FinancialModelPeriod period,
    required DateTime calculatedAt,
  }) {
    final periodFacts = snapshot.facts
        .where(
          (fact) =>
              fact.occurredAt == null || period.contains(fact.occurredAt!),
        )
        .toList();
    final limitations = <FinancialModelLimitation>[];

    if (snapshot.dataGaps.any(
      (gap) => gap.type == FinancialFactDataGapType.missingCategory,
    )) {
      limitations.add(FinancialModelLimitation.missingCategories);
    }
    if (snapshot.dataGaps.any(
      (gap) =>
          gap.type == FinancialFactDataGapType.missingAccountLink ||
          gap.type == FinancialFactDataGapType.missingAccountData,
    )) {
      limitations.add(FinancialModelLimitation.missingAccounts);
    }
    if (_currencies(periodFacts).length > 1) {
      limitations.add(FinancialModelLimitation.mixedCurrencies);
    }
    if (periodFacts.isEmpty) {
      limitations.add(FinancialModelLimitation.noMatchingFacts);
    }
    if (period.dayCount < 28) {
      limitations.add(FinancialModelLimitation.insufficientHistory);
    }

    final lowConfidenceCount = periodFacts
        .where((fact) => fact.confidence == FinancialFactConfidence.low)
        .length;
    final mediumConfidenceCount = periodFacts
        .where((fact) => fact.confidence == FinancialFactConfidence.medium)
        .length;
    final penalty =
        (snapshot.dataGaps.length * 12) +
        (lowConfidenceCount * 10) +
        (mediumConfidenceCount * 4) +
        (limitations.contains(FinancialModelLimitation.mixedCurrencies)
            ? 20
            : 0) +
        (limitations.contains(FinancialModelLimitation.insufficientHistory)
            ? 10
            : 0);
    final score = (100 - penalty).clamp(0, 100).toDouble();

    return resultBuilder.result(
      snapshot: snapshot,
      period: period,
      calculatedAt: calculatedAt,
      type: FinancialModelType.dataQualityScore,
      status: FinancialModelStatus.calculated,
      value: score,
      currencyCode: null,
      evidenceFacts: periodFacts,
      limitations: limitations.toSet().toList(),
      modelConfidence: FinancialModelConfidence.high,
      inputCoverage: score / 100,
    );
  }

  Set<String> _currencies(List<FinancialFact> facts) {
    return {
      for (final fact in facts)
        if (fact.currencyCode != null) fact.currencyCode!,
    };
  }
}
