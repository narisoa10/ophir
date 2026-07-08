import '../entities/financial_decision_option.dart';
import '../entities/financial_deviation.dart';
import '../entities/financial_explanation_evidence.dart';
import '../entities/financial_explanation_reference.dart';
import '../entities/financial_explanation_reference_type.dart';
import '../entities/financial_explanation_source_layer.dart';
import '../entities/financial_model_result.dart';
import '../entities/financial_problem.dart';
import '../entities/financial_recommendation.dart';
import '../entities/financial_rejected_alternative.dart';

final class FinancialExplanationEvidenceBuilder {
  const FinancialExplanationEvidenceBuilder();

  FinancialExplanationEvidence fromRecommendation(
    FinancialRecommendation recommendation,
  ) {
    return FinancialExplanationEvidence(
      evidenceId: 'evidence.${recommendation.recommendationId}',
      sourceEntityId: recommendation.recommendationId,
      references: _sortedReferences([
        FinancialExplanationReference(
          referenceId: recommendation.evidence.sourceOptionId,
          referenceType: FinancialExplanationReferenceType.decisionOption,
          sourceLayer: FinancialExplanationSourceLayer.decisionOption,
        ),
        ...recommendation.evidence.sourceProblemIds.map(
          (id) => FinancialExplanationReference(
            referenceId: id,
            referenceType: FinancialExplanationReferenceType.problem,
            sourceLayer: FinancialExplanationSourceLayer.problem,
          ),
        ),
        ...recommendation.evidence.sourceDeviationIds.map(
          (id) => FinancialExplanationReference(
            referenceId: id,
            referenceType: FinancialExplanationReferenceType.deviation,
            sourceLayer: FinancialExplanationSourceLayer.deviation,
          ),
        ),
        ...recommendation.evidence.sourceModelIds.map(
          (id) => FinancialExplanationReference(
            referenceId: id,
            referenceType: FinancialExplanationReferenceType.modelResult,
            sourceLayer: FinancialExplanationSourceLayer.model,
          ),
        ),
      ]),
    );
  }

  FinancialExplanationEvidence fromRejectedAlternative(
    FinancialRejectedAlternative alternative,
  ) {
    return FinancialExplanationEvidence(
      evidenceId: 'evidence.rejected.${alternative.optionId}',
      sourceEntityId: alternative.optionId,
      references: _sortedReferences([
        FinancialExplanationReference(
          referenceId: alternative.evidence.sourceOptionId,
          referenceType: FinancialExplanationReferenceType.decisionOption,
          sourceLayer: FinancialExplanationSourceLayer.decisionOption,
        ),
        ...alternative.evidence.sourceProblemIds.map(
          (id) => FinancialExplanationReference(
            referenceId: id,
            referenceType: FinancialExplanationReferenceType.problem,
            sourceLayer: FinancialExplanationSourceLayer.problem,
          ),
        ),
        ...alternative.evidence.sourceDeviationIds.map(
          (id) => FinancialExplanationReference(
            referenceId: id,
            referenceType: FinancialExplanationReferenceType.deviation,
            sourceLayer: FinancialExplanationSourceLayer.deviation,
          ),
        ),
        ...alternative.evidence.sourceModelIds.map(
          (id) => FinancialExplanationReference(
            referenceId: id,
            referenceType: FinancialExplanationReferenceType.modelResult,
            sourceLayer: FinancialExplanationSourceLayer.model,
          ),
        ),
      ]),
    );
  }

  FinancialExplanationEvidence fromOption(FinancialDecisionOption option) {
    return FinancialExplanationEvidence(
      evidenceId: 'evidence.${option.optionId}',
      sourceEntityId: option.optionId,
      references: _sortedReferences([
        ...option.evidence.sourceProblemIds.map(
          (id) => FinancialExplanationReference(
            referenceId: id,
            referenceType: FinancialExplanationReferenceType.problem,
            sourceLayer: FinancialExplanationSourceLayer.problem,
          ),
        ),
        ...option.evidence.sourceDeviationIds.map(
          (id) => FinancialExplanationReference(
            referenceId: id,
            referenceType: FinancialExplanationReferenceType.deviation,
            sourceLayer: FinancialExplanationSourceLayer.deviation,
          ),
        ),
        ...option.evidence.sourceModelIds.map(
          (id) => FinancialExplanationReference(
            referenceId: id,
            referenceType: FinancialExplanationReferenceType.modelResult,
            sourceLayer: FinancialExplanationSourceLayer.model,
          ),
        ),
      ]),
    );
  }

  FinancialExplanationEvidence fromProblem(FinancialProblem problem) {
    return FinancialExplanationEvidence(
      evidenceId: 'evidence.${problem.problemId}',
      sourceEntityId: problem.problemId,
      references: _sortedReferences([
        ...problem.evidence.sourceDeviationIds.map(
          (id) => FinancialExplanationReference(
            referenceId: id,
            referenceType: FinancialExplanationReferenceType.deviation,
            sourceLayer: FinancialExplanationSourceLayer.deviation,
          ),
        ),
        ...problem.evidence.sourceModelIds.map(
          (id) => FinancialExplanationReference(
            referenceId: id,
            referenceType: FinancialExplanationReferenceType.modelResult,
            sourceLayer: FinancialExplanationSourceLayer.model,
          ),
        ),
      ]),
    );
  }

  FinancialExplanationEvidence fromDeviation(FinancialDeviation deviation) {
    return FinancialExplanationEvidence(
      evidenceId: 'evidence.${deviation.deviationId}',
      sourceEntityId: deviation.deviationId,
      references: _sortedReferences([
        ...deviation.evidence.sourceModelIds.map(
          (id) => FinancialExplanationReference(
            referenceId: id,
            referenceType: FinancialExplanationReferenceType.modelResult,
            sourceLayer: FinancialExplanationSourceLayer.model,
          ),
        ),
        ...deviation.evidence.sourceModelEvidenceFactIds.map(
          (id) => FinancialExplanationReference(
            referenceId: id,
            referenceType: FinancialExplanationReferenceType.fact,
            sourceLayer: FinancialExplanationSourceLayer.fact,
          ),
        ),
      ]),
    );
  }

  FinancialExplanationEvidence fromModelResult(FinancialModelResult result) {
    return FinancialExplanationEvidence(
      evidenceId: 'evidence.${result.modelId}',
      sourceEntityId: result.modelId,
      references: _sortedReferences([
        ...result.evidence.factIds.map(
          (id) => FinancialExplanationReference(
            referenceId: id,
            referenceType: FinancialExplanationReferenceType.fact,
            sourceLayer: FinancialExplanationSourceLayer.fact,
          ),
        ),
      ]),
    );
  }

  List<FinancialExplanationReference> _sortedReferences(
    Iterable<FinancialExplanationReference> references,
  ) {
    final values = references.toList();
    values.sort((a, b) {
      final type = a.referenceType.index.compareTo(b.referenceType.index);
      if (type != 0) {
        return type;
      }
      return a.referenceId.compareTo(b.referenceId);
    });
    return List.unmodifiable(values);
  }
}
