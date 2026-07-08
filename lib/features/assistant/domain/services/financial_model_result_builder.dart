import '../entities/financial_fact.dart';
import '../entities/financial_fact_confidence.dart';
import '../entities/financial_fact_data_gap.dart';
import '../entities/financial_model_catalog.dart';
import '../entities/financial_model_confidence.dart';
import '../entities/financial_model_evidence.dart';
import '../entities/financial_model_limitation.dart';
import '../entities/financial_model_metadata.dart';
import '../entities/financial_model_period.dart';
import '../entities/financial_model_result.dart';
import '../entities/financial_model_status.dart';
import '../entities/financial_model_type.dart';
import '../entities/financial_model_unit.dart';
import '../entities/financial_facts_snapshot.dart';

final class FinancialModelResultBuilder {
  const FinancialModelResultBuilder({
    this.engineVersion = 'financial-models-v1',
  });

  final String engineVersion;

  FinancialModelMetadata metadata({
    required FinancialFactsSnapshot snapshot,
    required DateTime calculatedAt,
  }) {
    return FinancialModelMetadata(
      calculatedAt: calculatedAt,
      engineVersion: engineVersion,
      snapshotVersion:
          'facts:${snapshot.facts.length}:gaps:${snapshot.dataGaps.length}',
    );
  }

  FinancialModelResult result({
    required FinancialModelType type,
    required FinancialModelStatus status,
    required double? value,
    required FinancialModelPeriod period,
    required DateTime calculatedAt,
    required FinancialFactsSnapshot snapshot,
    required List<FinancialFact> evidenceFacts,
    required List<FinancialModelLimitation> limitations,
    required FinancialModelConfidence modelConfidence,
    String? currencyCode,
    List<String> assumptions = const [],
    double? inputCoverage,
    List<FinancialModelResult> breakdown = const [],
  }) {
    final definition = FinancialModelCatalog.definitionFor(type);
    final gaps = snapshot.dataGaps;
    return FinancialModelResult(
      modelId: definition?.id ?? FinancialModelCatalog.dataQualityScore.id,
      modelType: type,
      status: status,
      value: value,
      unit: definition?.unit ?? FinancialModelUnit.none,
      period: period,
      currencyCode: currencyCode,
      dataConfidence: _dataConfidence(evidenceFacts, gaps, limitations),
      modelConfidence: modelConfidence,
      evidence: FinancialModelEvidence(
        factIds: List.unmodifiable(evidenceFacts.map((fact) => fact.id)),
        dataGapSourceIds: const [],
      ),
      assumptions: List.unmodifiable(assumptions),
      limitations: List.unmodifiable(limitations),
      inputCoverage: inputCoverage ?? _coverage(evidenceFacts, gaps),
      metadata: metadata(snapshot: snapshot, calculatedAt: calculatedAt),
      breakdown: List.unmodifiable(breakdown),
    );
  }

  FinancialModelConfidence _dataConfidence(
    List<FinancialFact> facts,
    List<FinancialFactDataGap> gaps,
    List<FinancialModelLimitation> limitations,
  ) {
    if (facts.isEmpty ||
        limitations.contains(FinancialModelLimitation.mixedCurrencies)) {
      return FinancialModelConfidence.none;
    }
    if (facts.any((fact) => fact.confidence == FinancialFactConfidence.low)) {
      return FinancialModelConfidence.low;
    }
    if (gaps.isNotEmpty ||
        facts.any(
          (fact) => fact.confidence == FinancialFactConfidence.medium,
        )) {
      return FinancialModelConfidence.medium;
    }
    return FinancialModelConfidence.high;
  }

  double _coverage(List<FinancialFact> facts, List<FinancialFactDataGap> gaps) {
    final total = facts.length + gaps.length;
    if (total == 0) {
      return 0;
    }
    return facts.length / total;
  }

  FinancialModelResult unsupportedResult({
    required FinancialModelType type,
    required FinancialModelPeriod period,
    required DateTime calculatedAt,
    required FinancialFactsSnapshot snapshot,
  }) {
    final definition = FinancialModelCatalog.definitionFor(type);
    return FinancialModelResult(
      modelId: definition?.id ?? 'financial.model.unsupported',
      modelType: type,
      status: FinancialModelStatus.unsupported,
      value: null,
      unit: definition?.unit ?? FinancialModelUnit.none,
      period: period,
      currencyCode: null,
      dataConfidence: FinancialModelConfidence.none,
      modelConfidence: FinancialModelConfidence.none,
      evidence: const FinancialModelEvidence(factIds: [], dataGapSourceIds: []),
      assumptions: const [],
      limitations: const [FinancialModelLimitation.unsupportedModel],
      inputCoverage: 0,
      metadata: metadata(snapshot: snapshot, calculatedAt: calculatedAt),
      breakdown: const [],
    );
  }
}
