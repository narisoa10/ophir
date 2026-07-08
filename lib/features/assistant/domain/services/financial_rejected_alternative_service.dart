import '../entities/financial_decision_option.dart';
import '../entities/financial_decision_option_applicability.dart';
import '../entities/financial_rejected_alternative.dart';
import '../entities/financial_rejected_alternative_reason.dart';
import '../entities/financial_recommendation_evaluation.dart';
import '../entities/financial_recommendation_evidence.dart';
import 'financial_recommendation_selection_policy.dart';

final class FinancialRejectedAlternativeService {
  const FinancialRejectedAlternativeService({
    this.selectionPolicy = const FinancialRecommendationSelectionPolicy(),
  });

  final FinancialRecommendationSelectionPolicy selectionPolicy;

  List<FinancialRejectedAlternative> alternatives({
    required List<FinancialDecisionOption> options,
    required FinancialRecommendationEvaluation selectedEvaluation,
    required Map<String, FinancialRecommendationEvaluation> evaluationsById,
    required Set<String> executableOptionIds,
  }) {
    return List.unmodifiable(
      options
          .where((option) => option.optionId != selectedEvaluation.optionId)
          .map(
            (option) => FinancialRejectedAlternative(
              optionId: option.optionId,
              optionType: option.optionType,
              reasonCodes: List.unmodifiable(
                _reasonsFor(
                  option: option,
                  selectedEvaluation: selectedEvaluation,
                  candidateEvaluation: evaluationsById[option.optionId],
                  executableOptionIds: executableOptionIds,
                ),
              ),
              evidence: _evidenceFor(option),
            ),
          ),
    );
  }

  FinancialRecommendationEvidence _evidenceFor(FinancialDecisionOption option) {
    return FinancialRecommendationEvidence(
      sourceOptionId: option.optionId,
      sourceProblemIds: option.evidence.sourceProblemIds,
      sourceProblemTypes: List.unmodifiable(
        option.evidence.sourceProblemTypes.map((type) => type.name),
      ),
      sourceDeviationIds: option.evidence.sourceDeviationIds,
      sourceModelIds: option.evidence.sourceModelIds,
    );
  }

  List<FinancialRejectedAlternativeReason> _reasonsFor({
    required FinancialDecisionOption option,
    required FinancialRecommendationEvaluation selectedEvaluation,
    required FinancialRecommendationEvaluation? candidateEvaluation,
    required Set<String> executableOptionIds,
  }) {
    if (option.applicability ==
        FinancialDecisionOptionApplicability.futureUnavailable) {
      return [FinancialRejectedAlternativeReason.futureUnavailable];
    }
    if (option.applicability ==
        FinancialDecisionOptionApplicability.notApplicable) {
      return [FinancialRejectedAlternativeReason.notApplicable];
    }
    if (!executableOptionIds.contains(option.optionId)) {
      return [
        FinancialRejectedAlternativeReason.conditionalWhileApplicableExists,
      ];
    }
    if (candidateEvaluation == null) {
      return [FinancialRejectedAlternativeReason.deterministicTieBreak];
    }

    final reasons = <FinancialRejectedAlternativeReason>[];
    if (candidateEvaluation.expectedImpact <
        selectedEvaluation.expectedImpact) {
      reasons.add(FinancialRejectedAlternativeReason.lowerExpectedImpact);
    }
    if (candidateEvaluation.cost > selectedEvaluation.cost) {
      reasons.add(FinancialRejectedAlternativeReason.higherCost);
    }
    if (candidateEvaluation.risk > selectedEvaluation.risk) {
      reasons.add(FinancialRejectedAlternativeReason.higherRisk);
    }
    if (candidateEvaluation.confidence < selectedEvaluation.confidence) {
      reasons.add(FinancialRejectedAlternativeReason.lowerConfidence);
    }
    if (candidateEvaluation.urgency < selectedEvaluation.urgency) {
      reasons.add(FinancialRejectedAlternativeReason.weakerUrgency);
    }
    if (candidateEvaluation.reversibility.index <
        selectedEvaluation.reversibility.index) {
      reasons.add(FinancialRejectedAlternativeReason.lowerReversibility);
    }
    if (candidateEvaluation.horizon < selectedEvaluation.horizon) {
      reasons.add(FinancialRejectedAlternativeReason.lessSuitableHorizon);
    }
    if (candidateEvaluation.mayWorsenProblemCount >
        selectedEvaluation.mayWorsenProblemCount) {
      reasons.add(FinancialRejectedAlternativeReason.mayWorsenMoreProblems);
    }
    if (reasons.isEmpty &&
        selectionPolicy.compare(candidateEvaluation, selectedEvaluation) > 0) {
      reasons.add(FinancialRejectedAlternativeReason.deterministicTieBreak);
    }
    return reasons.isEmpty
        ? [FinancialRejectedAlternativeReason.deterministicTieBreak]
        : reasons;
  }
}
