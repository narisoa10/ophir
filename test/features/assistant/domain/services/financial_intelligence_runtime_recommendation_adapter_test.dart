import 'package:flutter_test/flutter_test.dart';
import 'package:ophir/features/assistant/domain/entities/financial_decision_option_type.dart';
import 'package:ophir/features/assistant/domain/entities/financial_intelligence_decision_option.dart';
import 'package:ophir/features/assistant/domain/entities/financial_intelligence_decision_option_type.dart';
import 'package:ophir/features/assistant/domain/entities/financial_intelligence_problem_type.dart';
import 'package:ophir/features/assistant/domain/entities/financial_intelligence_recommendation_evidence.dart';
import 'package:ophir/features/assistant/domain/entities/financial_intelligence_recommendation_explanation.dart';
import 'package:ophir/features/assistant/domain/entities/financial_intelligence_recommendation_explanation_snapshot.dart';
import 'package:ophir/features/assistant/domain/entities/financial_intelligence_recommendation_selection.dart';
import 'package:ophir/features/assistant/domain/entities/financial_intelligence_recommendation_selection_reason.dart';
import 'package:ophir/features/assistant/domain/entities/financial_intelligence_recommendation_selection_snapshot.dart';
import 'package:ophir/features/assistant/domain/entities/financial_intelligence_recommendation_type.dart';
import 'package:ophir/features/assistant/domain/entities/financial_model_period.dart';
import 'package:ophir/features/assistant/domain/entities/financial_recommendation_conflict_level.dart';
import 'package:ophir/features/assistant/domain/services/financial_intelligence_runtime_recommendation_adapter.dart';

import '../../helpers/financial_recommendation_test_helpers.dart';

void main() {
  const adapter = FinancialIntelligenceRuntimeRecommendationAdapter();
  final generatedAt = DateTime.utc(2035, 6);

  group('FinancialIntelligenceRuntimeRecommendationAdapter', () {
    test('allowlisted intelligence options map to legacy runtime types', () {
      final cases = {
        FinancialIntelligenceDecisionOptionType.reviewOrdinarySpendingStructure:
            FinancialDecisionOptionType.reviewExpenseStructure,
        FinancialIntelligenceDecisionOptionType.reduceReducibleSpending:
            FinancialDecisionOptionType.reduceDiscretionarySpending,
        FinancialIntelligenceDecisionOptionType
                .deferOrReduceDiscretionarySpending:
            FinancialDecisionOptionType.deferOptionalSpending,
        FinancialIntelligenceDecisionOptionType.improveCategoryCoverage:
            FinancialDecisionOptionType.improveCategorization,
      };

      for (final entry in cases.entries) {
        final selection = _selection(_option(entry.key));
        final candidate = adapter.build(
          selection: selection,
          explanation: _explanation(selection),
          comparison: buildTestRecommendationComparison(
            legacyType: entry.value,
            shadowTypes: [_comparisonType(entry.key)],
            conflictLevel: FinancialRecommendationConflictLevel.aligned,
          ),
          generatedAt: generatedAt,
        );

        expect(candidate.isEligibleForRuntime, isTrue, reason: entry.key.name);
        expect(candidate.blockReasons, isEmpty);
        expect(
          candidate.adaptedRecommendation?.selectedOptionType,
          entry.value,
        );
        expect(candidate.adaptedExplanation, isNotNull);
        expect(candidate.isDiagnosticsOnlySource, isTrue);
        expect(
          candidate.adaptedExplanation?.graph.nodes.first.referencedEntityIds,
          contains(candidate.adaptedRecommendation?.recommendationId),
        );
      }
    });

    test('blocked intelligence options return blocked candidate', () {
      const blockedTypes = [
        FinancialIntelligenceDecisionOptionType.reviewMandatoryCosts,
        FinancialIntelligenceDecisionOptionType.maintainAssetBuildingMomentum,
        FinancialIntelligenceDecisionOptionType.maintainDebtReductionMomentum,
        FinancialIntelligenceDecisionOptionType.reviewTransactionContext,
      ];

      for (final type in blockedTypes) {
        final selection = _selection(_option(type));
        final candidate = adapter.build(
          selection: selection,
          explanation: _explanation(selection),
          comparison: buildTestRecommendationComparison(
            legacyType: FinancialDecisionOptionType.reviewExpenseStructure,
            shadowTypes: [_comparisonType(type)],
            conflictLevel: FinancialRecommendationConflictLevel.aligned,
          ),
          generatedAt: generatedAt,
        );

        expect(candidate.isEligibleForRuntime, isFalse, reason: type.name);
        expect(candidate.adaptedRecommendation, isNull);
        expect(candidate.adaptedExplanation, isNull);
        expect(
          candidate.blockReasons,
          contains('unsupportedIntelligenceOption'),
        );
      }
    });

    test('invalid explanation blocks candidate', () {
      final selection = _selection(
        _option(
          FinancialIntelligenceDecisionOptionType.reduceReducibleSpending,
        ),
      );

      final candidate = adapter.build(
        selection: selection,
        explanation: _explanation(selection, includeEvidence: false),
        comparison: buildTestRecommendationComparison(
          legacyType: FinancialDecisionOptionType.reduceDiscretionarySpending,
          shadowTypes: const [
            FinancialIntelligenceRecommendationType.reduceReducibleSpending,
          ],
          conflictLevel: FinancialRecommendationConflictLevel.aligned,
        ),
        generatedAt: generatedAt,
      );

      expect(candidate.isEligibleForRuntime, isFalse);
      expect(candidate.adaptedRecommendation, isNull);
      expect(candidate.adaptedExplanation, isNull);
      expect(candidate.blockReasons, contains('invalidExplanation'));
    });

    test('non diagnostics-only source blocks candidate', () {
      final selection = _selection(
        _option(
          FinancialIntelligenceDecisionOptionType
              .reviewOrdinarySpendingStructure,
          isDiagnosticsOnly: false,
        ),
      );

      final candidate = adapter.build(
        selection: selection,
        explanation: _explanation(selection),
        comparison: buildTestRecommendationComparison(
          legacyType: FinancialDecisionOptionType.reviewExpenseStructure,
          shadowTypes: const [
            FinancialIntelligenceRecommendationType
                .reviewOrdinarySpendingStructure,
          ],
          conflictLevel: FinancialRecommendationConflictLevel.aligned,
        ),
        generatedAt: generatedAt,
      );

      expect(candidate.isEligibleForRuntime, isFalse);
      expect(candidate.blockReasons, contains('sourceNotDiagnosticsOnly'));
    });
  });
}

FinancialIntelligenceRecommendationSelectionSnapshot _selection(
  FinancialIntelligenceDecisionOption selected, {
  List<FinancialIntelligenceDecisionOption> rejected = const [],
}) {
  return FinancialIntelligenceRecommendationSelectionSnapshot(
    selection: FinancialIntelligenceRecommendationSelection(
      selectedOption: selected,
      rejectedOptions: rejected,
      selectionReason:
          FinancialIntelligenceRecommendationSelectionReason.priorityOrder,
      isDiagnosticsOnly: true,
    ),
  );
}

FinancialIntelligenceRecommendationExplanationSnapshot _explanation(
  FinancialIntelligenceRecommendationSelectionSnapshot selection, {
  bool includeEvidence = true,
}) {
  final selected = selection.selectedOption;

  return FinancialIntelligenceRecommendationExplanationSnapshot(
    explanation: FinancialIntelligenceRecommendationExplanation(
      selectedRecommendation: selected,
      selectionReason: selection.selectionReason,
      supportingProblems: const [],
      supportingParityMetrics: const [],
      evidence: [
        if (includeEvidence && selected != null)
          FinancialIntelligenceRecommendationEvidence(
            evidenceId: 'evidence.${selected.optionId}',
            sourceOptionId: selected.optionId,
            sourceProblemIds: selected.sourceProblemIds,
            sourceProblemTypes: selected.sourceProblemTypes,
            sourceDeviationIds: const [],
            sourceDeviationTypes: const [],
            parityMetrics: const [],
            isDiagnosticsOnly: true,
          ),
      ],
      isDiagnosticsOnly: true,
    ),
  );
}

FinancialIntelligenceDecisionOption _option(
  FinancialIntelligenceDecisionOptionType type, {
  bool isDiagnosticsOnly = true,
}) {
  return FinancialIntelligenceDecisionOption(
    optionId: 'option.${type.name}',
    type: type,
    period: FinancialModelPeriod(
      start: DateTime.utc(2035, 6),
      end: DateTime.utc(2035, 7),
    ),
    sourceProblemIds: ['problem.${type.name}'],
    sourceProblemTypes: [_problemType(type)],
    parityMetric: null,
    parityStatus: null,
    legacyModelValue: null,
    intelligenceModelValue: null,
    isPositiveSignal:
        type ==
            FinancialIntelligenceDecisionOptionType
                .maintainAssetBuildingMomentum ||
        type ==
            FinancialIntelligenceDecisionOptionType
                .maintainDebtReductionMomentum,
    isWarning: true,
    isDiagnosticsOnly: isDiagnosticsOnly,
  );
}

FinancialIntelligenceProblemType _problemType(
  FinancialIntelligenceDecisionOptionType type,
) {
  return switch (type) {
    FinancialIntelligenceDecisionOptionType.reviewOrdinarySpendingStructure =>
      FinancialIntelligenceProblemType.ordinarySpendingPressure,
    FinancialIntelligenceDecisionOptionType.reviewMandatoryCosts =>
      FinancialIntelligenceProblemType.mandatoryCostPressure,
    FinancialIntelligenceDecisionOptionType.reduceReducibleSpending =>
      FinancialIntelligenceProblemType.reducibleSpendingPressure,
    FinancialIntelligenceDecisionOptionType
        .deferOrReduceDiscretionarySpending =>
      FinancialIntelligenceProblemType.discretionarySpendingPressure,
    FinancialIntelligenceDecisionOptionType.maintainAssetBuildingMomentum =>
      FinancialIntelligenceProblemType.positiveAssetBuildingSignal,
    FinancialIntelligenceDecisionOptionType.maintainDebtReductionMomentum =>
      FinancialIntelligenceProblemType.debtReductionSignal,
    FinancialIntelligenceDecisionOptionType.reviewTransactionContext =>
      FinancialIntelligenceProblemType.transactionContextRequired,
    FinancialIntelligenceDecisionOptionType.improveCategoryCoverage =>
      FinancialIntelligenceProblemType.classificationCoverageGap,
  };
}

FinancialIntelligenceRecommendationType _comparisonType(
  FinancialIntelligenceDecisionOptionType type,
) {
  return switch (type) {
    FinancialIntelligenceDecisionOptionType.reviewOrdinarySpendingStructure =>
      FinancialIntelligenceRecommendationType.reviewOrdinarySpendingStructure,
    FinancialIntelligenceDecisionOptionType.reviewMandatoryCosts =>
      FinancialIntelligenceRecommendationType.reviewMandatoryCosts,
    FinancialIntelligenceDecisionOptionType.reduceReducibleSpending =>
      FinancialIntelligenceRecommendationType.reduceReducibleSpending,
    FinancialIntelligenceDecisionOptionType
        .deferOrReduceDiscretionarySpending =>
      FinancialIntelligenceRecommendationType
          .deferOrReduceDiscretionarySpending,
    FinancialIntelligenceDecisionOptionType.maintainAssetBuildingMomentum =>
      FinancialIntelligenceRecommendationType.maintainAssetBuildingMomentum,
    FinancialIntelligenceDecisionOptionType.maintainDebtReductionMomentum =>
      FinancialIntelligenceRecommendationType.maintainDebtReductionMomentum,
    FinancialIntelligenceDecisionOptionType.reviewTransactionContext =>
      FinancialIntelligenceRecommendationType.reviewTransactionContext,
    FinancialIntelligenceDecisionOptionType.improveCategoryCoverage =>
      FinancialIntelligenceRecommendationType.improveCategoryCoverage,
  };
}
