import '../entities/financial_deviation.dart';
import '../entities/financial_deviation_evidence.dart';
import '../entities/financial_deviation_metadata.dart';
import '../entities/financial_deviation_status.dart';
import '../entities/financial_deviation_threshold.dart';
import '../entities/financial_deviation_type.dart';
import '../entities/financial_model_result.dart';
import 'financial_deviation_confidence_service.dart';
import 'financial_deviation_severity_policy.dart';

final class FinancialDeviationResultBuilder {
  const FinancialDeviationResultBuilder({
    this.engineVersion = 'financial-deviations-v1',
    this.confidenceService = const FinancialDeviationConfidenceService(),
    this.severityPolicy = const FinancialDeviationSeverityPolicy(),
  });

  final String engineVersion;
  final FinancialDeviationConfidenceService confidenceService;
  final FinancialDeviationSeverityPolicy severityPolicy;

  FinancialDeviation calculated({
    required FinancialDeviationType type,
    required double actualValue,
    required double deviationAmount,
    required FinancialDeviationThreshold threshold,
    required List<FinancialModelResult> sourceModels,
  }) {
    final primary = sourceModels.first;
    final limitations = confidenceService.limitationsFor(sourceModels);
    return FinancialDeviation(
      deviationId: 'financial.deviation.${type.name}',
      deviationType: type,
      status: FinancialDeviationStatus.calculated,
      severity: severityPolicy.severityFor(
        deviationAmount: deviationAmount,
        thresholdValue: threshold.expectedValue.thresholdValue,
      ),
      actualValue: actualValue,
      expectedValue: threshold.expectedValue,
      deviationAmount: deviationAmount,
      unit: threshold.expectedValue.unit,
      period: primary.period,
      confidence: confidenceService.confidenceFor(sourceModels),
      evidence: FinancialDeviationEvidence(
        sourceModelIds: List.unmodifiable(
          sourceModels.map((model) => model.modelId),
        ),
        sourceModelEvidenceFactIds: List.unmodifiable(
          sourceModels.expand((model) => model.evidence.factIds).toSet(),
        ),
      ),
      limitations: List.unmodifiable(limitations),
      metadata: FinancialDeviationMetadata(
        calculatedAt: primary.metadata.calculatedAt,
        engineVersion: engineVersion,
        thresholdId: threshold.id,
      ),
    );
  }
}
