import '../entities/financial_decision_option.dart';
import '../entities/financial_recommendation.dart';
import '../entities/financial_recommendation_confidence.dart';
import '../entities/financial_recommendation_evidence.dart';
import '../entities/financial_recommendation_metadata.dart';
import '../entities/financial_recommendation_status.dart';
import 'financial_rejected_alternative_service.dart';
import 'financial_recommendation_eligibility_policy.dart';
import 'financial_recommendation_evaluation_service.dart';
import 'financial_recommendation_priority_policy.dart';
import 'financial_recommendation_selection_policy.dart';

final class FinancialRecommendationService {
  const FinancialRecommendationService({
    required this.generatedAt,
    this.engineVersion = 'financial-recommendations-v1',
    this.eligibilityPolicy = const FinancialRecommendationEligibilityPolicy(),
    this.evaluationService = const FinancialRecommendationEvaluationService(),
    this.selectionPolicy = const FinancialRecommendationSelectionPolicy(),
    this.priorityPolicy = const FinancialRecommendationPriorityPolicy(),
    this.rejectedAlternativeService =
        const FinancialRejectedAlternativeService(),
  });

  final DateTime generatedAt;
  final String engineVersion;
  final FinancialRecommendationEligibilityPolicy eligibilityPolicy;
  final FinancialRecommendationEvaluationService evaluationService;
  final FinancialRecommendationSelectionPolicy selectionPolicy;
  final FinancialRecommendationPriorityPolicy priorityPolicy;
  final FinancialRejectedAlternativeService rejectedAlternativeService;

  FinancialRecommendation? recommend(List<FinancialDecisionOption> options) {
    final executable = eligibilityPolicy.executableOptions(options);
    if (executable.isEmpty) {
      return null;
    }

    final evaluations = [
      for (final option in executable) evaluationService.evaluate(option),
    ];
    final evaluationsById = {
      for (final option in options)
        option.optionId: evaluationService.evaluate(option),
    };
    final selectedEvaluation = selectionPolicy.select(evaluations);
    final selectedOption = executable.singleWhere(
      (option) => option.optionId == selectedEvaluation.optionId,
    );
    final executableOptionIds = executable
        .map((option) => option.optionId)
        .toSet();

    return FinancialRecommendation(
      recommendationId:
          'financial.recommendation.${selectedOption.optionType.name}.'
          '${selectedOption.optionId}',
      selectedOption: selectedOption,
      selectedOptionId: selectedOption.optionId,
      selectedOptionType: selectedOption.optionType,
      status: FinancialRecommendationStatus.selected,
      priority: priorityPolicy.priorityFor(selectedEvaluation),
      confidence: _confidenceFor(selectedEvaluation.confidence),
      evaluation: selectedEvaluation,
      rejectedAlternatives: rejectedAlternativeService.alternatives(
        options: options,
        selectedEvaluation: selectedEvaluation,
        evaluationsById: evaluationsById,
        executableOptionIds: executableOptionIds,
      ),
      evidence: FinancialRecommendationEvidence(
        sourceOptionId: selectedOption.optionId,
        sourceProblemIds: selectedOption.evidence.sourceProblemIds,
        sourceProblemTypes: List.unmodifiable(
          selectedOption.evidence.sourceProblemTypes.map((type) => type.name),
        ),
        sourceDeviationIds: selectedOption.evidence.sourceDeviationIds,
        sourceModelIds: selectedOption.evidence.sourceModelIds,
      ),
      metadata: FinancialRecommendationMetadata(
        generatedAt: generatedAt,
        engineVersion: engineVersion,
      ),
    );
  }

  FinancialRecommendationConfidence _confidenceFor(int value) {
    if (value >= 3) {
      return FinancialRecommendationConfidence.high;
    }
    if (value == 2) {
      return FinancialRecommendationConfidence.medium;
    }
    if (value == 1) {
      return FinancialRecommendationConfidence.low;
    }
    return FinancialRecommendationConfidence.none;
  }
}
