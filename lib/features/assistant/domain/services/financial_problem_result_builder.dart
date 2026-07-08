import '../entities/financial_deviation.dart';
import '../entities/financial_problem.dart';
import '../entities/financial_problem_evidence.dart';
import '../entities/financial_problem_metadata.dart';
import '../entities/financial_problem_rule.dart';
import '../entities/financial_problem_signal.dart';
import '../entities/financial_problem_status.dart';
import 'financial_problem_confidence_service.dart';
import 'financial_problem_severity_policy.dart';

final class FinancialProblemResultBuilder {
  const FinancialProblemResultBuilder({
    this.engineVersion = 'financial-problems-v1',
    this.confidenceService = const FinancialProblemConfidenceService(),
    this.severityPolicy = const FinancialProblemSeverityPolicy(),
  });

  final String engineVersion;
  final FinancialProblemConfidenceService confidenceService;
  final FinancialProblemSeverityPolicy severityPolicy;

  FinancialProblem detected({
    required FinancialProblemRule rule,
    required List<FinancialDeviation> requiredDeviations,
    required List<FinancialDeviation> supportingDeviations,
    required bool hasWeakDataQuality,
    required bool hasLimitedSupportingEvidence,
  }) {
    final sourceDeviations = [...requiredDeviations, ...supportingDeviations];
    final primary = requiredDeviations.first;
    final confidence = confidenceService.confidenceFor(
      requiredDeviations: requiredDeviations,
      supportingDeviations: supportingDeviations,
      hasWeakDataQuality: hasWeakDataQuality,
    );

    return FinancialProblem(
      problemId:
          'financial.problem.${rule.problemType.name}.'
          '${primary.period.start.microsecondsSinceEpoch}.'
          '${primary.period.end.microsecondsSinceEpoch}',
      problemType: rule.problemType,
      status: FinancialProblemStatus.detected,
      severity: severityPolicy.severityFor(
        requiredDeviations: requiredDeviations,
        supportingDeviations: supportingDeviations,
        confidence: confidence,
        hasWeakDataQuality: hasWeakDataQuality,
      ),
      confidence: confidence,
      impact: rule.impact,
      period: primary.period,
      signals: List.unmodifiable([
        ...requiredDeviations.map(
          (deviation) => FinancialProblemSignal(
            deviationId: deviation.deviationId,
            deviationType: deviation.deviationType,
            severity: deviation.severity,
            confidence: deviation.confidence,
            isPrimary: true,
          ),
        ),
        ...supportingDeviations.map(
          (deviation) => FinancialProblemSignal(
            deviationId: deviation.deviationId,
            deviationType: deviation.deviationType,
            severity: deviation.severity,
            confidence: deviation.confidence,
            isPrimary: false,
          ),
        ),
      ]),
      evidence: FinancialProblemEvidence(
        sourceDeviationIds: List.unmodifiable(
          sourceDeviations.map((deviation) => deviation.deviationId).toSet(),
        ),
        sourceDeviationTypes: List.unmodifiable(
          sourceDeviations.map((deviation) => deviation.deviationType).toSet(),
        ),
        sourceModelIds: List.unmodifiable(
          sourceDeviations
              .expand((deviation) => deviation.evidence.sourceModelIds)
              .toSet(),
        ),
      ),
      limitations: List.unmodifiable(
        confidenceService.limitationsFor(
          deviations: sourceDeviations,
          hasWeakDataQuality: hasWeakDataQuality,
          hasLimitedSupportingEvidence: hasLimitedSupportingEvidence,
        ),
      ),
      metadata: FinancialProblemMetadata(
        calculatedAt: primary.metadata.calculatedAt,
        engineVersion: engineVersion,
        ruleId: rule.id,
      ),
    );
  }
}
