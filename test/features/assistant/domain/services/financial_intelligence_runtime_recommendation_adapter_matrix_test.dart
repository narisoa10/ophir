import 'package:flutter_test/flutter_test.dart';
import 'package:ophir/features/assistant/domain/entities/financial_decision_option_type.dart';
import 'package:ophir/features/assistant/domain/entities/financial_intelligence_decision_option.dart';
import 'package:ophir/features/assistant/domain/entities/financial_intelligence_decision_option_type.dart';
import 'package:ophir/features/assistant/domain/entities/financial_intelligence_decision_options_snapshot.dart';
import 'package:ophir/features/assistant/domain/entities/financial_intelligence_model_parity_metric.dart';
import 'package:ophir/features/assistant/domain/entities/financial_intelligence_model_parity_metric_result.dart';
import 'package:ophir/features/assistant/domain/entities/financial_intelligence_model_parity_snapshot.dart';
import 'package:ophir/features/assistant/domain/entities/financial_intelligence_model_parity_status.dart';
import 'package:ophir/features/assistant/domain/entities/financial_intelligence_problem.dart';
import 'package:ophir/features/assistant/domain/entities/financial_intelligence_problem_type.dart';
import 'package:ophir/features/assistant/domain/entities/financial_intelligence_problems_snapshot.dart';
import 'package:ophir/features/assistant/domain/entities/financial_intelligence_recommendation.dart';
import 'package:ophir/features/assistant/domain/entities/financial_intelligence_recommendation_diagnostics_snapshot.dart';
import 'package:ophir/features/assistant/domain/entities/financial_intelligence_recommendation_explanation_snapshot.dart';
import 'package:ophir/features/assistant/domain/entities/financial_intelligence_recommendation_selection_reason.dart';
import 'package:ophir/features/assistant/domain/entities/financial_intelligence_recommendation_selection_snapshot.dart';
import 'package:ophir/features/assistant/domain/entities/financial_intelligence_recommendation_type.dart';
import 'package:ophir/features/assistant/domain/entities/financial_model_period.dart';
import 'package:ophir/features/assistant/domain/entities/financial_problem_impact.dart';
import 'package:ophir/features/assistant/domain/entities/financial_problem_severity.dart';
import 'package:ophir/features/assistant/domain/entities/financial_recommendation_comparison_flag.dart';
import 'package:ophir/features/assistant/domain/entities/financial_recommendation_comparison_read_model.dart';
import 'package:ophir/features/assistant/domain/entities/financial_recommendation_conflict_level.dart';
import 'package:ophir/features/assistant/domain/entities/financial_runtime_recommendation_mode.dart';
import 'package:ophir/features/assistant/domain/entities/financial_runtime_recommendation_selection.dart';
import 'package:ophir/features/assistant/domain/entities/financial_runtime_recommendation_source.dart';
import 'package:ophir/features/assistant/domain/services/financial_intelligence_recommendation_explanation_service.dart';
import 'package:ophir/features/assistant/domain/services/financial_intelligence_recommendation_selection_service.dart';
import 'package:ophir/features/assistant/domain/services/financial_intelligence_runtime_recommendation_adapter.dart';
import 'package:ophir/features/assistant/domain/services/financial_recommendation_comparison_service.dart';
import 'package:ophir/features/assistant/domain/services/financial_runtime_recommendation_policy.dart';

import '../../helpers/financial_recommendation_test_helpers.dart';

void main() {
  const selectionService =
      FinancialIntelligenceRecommendationSelectionService();
  const explanationService =
      FinancialIntelligenceRecommendationExplanationService();
  const comparisonService = FinancialRecommendationComparisonService();
  const adapter = FinancialIntelligenceRuntimeRecommendationAdapter();
  const policy = FinancialRuntimeRecommendationPolicy();

  group('FinancialIntelligenceRuntimeRecommendationAdapter matrix', () {
    test(
      'covers adapter, selection, comparison, and allowlist runtime routing',
      () {
        for (final fixture in _fixtures()) {
          final evaluation = _evaluate(
            fixture,
            selectionService: selectionService,
            explanationService: explanationService,
            comparisonService: comparisonService,
            adapter: adapter,
            policy: policy,
          );

          expect(
            evaluation.legacyRecommendation.selectedOptionType,
            fixture.legacyType,
            reason: fixture.name,
          );
          expect(
            evaluation.selection.selectionReason,
            FinancialIntelligenceRecommendationSelectionReason.priorityOrder,
            reason: fixture.name,
          );
          expect(
            evaluation.selection.selectedOption?.type,
            fixture.expectedSelectedType,
            reason: fixture.name,
          );
          expect(
            evaluation.selection.rejectedOptions
                .map((option) => option.type)
                .toSet(),
            fixture.expectedRejectedTypes.toSet(),
            reason: fixture.name,
          );
          expect(
            evaluation.comparison.legacyRecommendationType,
            fixture.legacyType,
            reason: fixture.name,
          );
          expect(
            evaluation.comparison.shadowRecommendationTypes,
            fixture.shadowTypes,
            reason: fixture.name,
          );
          expect(
            evaluation.comparison.conflictLevel,
            fixture.expectedConflictLevel,
            reason: fixture.name,
          );
          expect(
            evaluation.comparison.hasPositiveSignals,
            fixture.hasPositiveSignals,
            reason: fixture.name,
          );
          expect(
            evaluation.comparison.hasContextWarnings,
            fixture.hasContextWarnings,
            reason: fixture.name,
          );
          expect(
            evaluation.comparison.hasCoverageWarnings,
            fixture.hasCoverageWarnings,
            reason: fixture.name,
          );
          expect(
            evaluation.comparison.flags,
            fixture.expectedFlags,
            reason: fixture.name,
          );

          expect(
            evaluation.candidate.isEligibleForRuntime,
            fixture.isCandidateEligible,
            reason: fixture.name,
          );
          expect(
            evaluation.candidate.isDiagnosticsOnlySource,
            isTrue,
            reason: fixture.name,
          );

          if (fixture.isCandidateEligible) {
            final adaptedRecommendation =
                evaluation.candidate.adaptedRecommendation;
            final adaptedExplanation = evaluation.candidate.adaptedExplanation;

            expect(adaptedRecommendation, isNotNull, reason: fixture.name);
            expect(
              adaptedRecommendation!.selectedOptionType,
              fixture.legacyType,
              reason: fixture.name,
            );
            expect(adaptedExplanation, isNotNull, reason: fixture.name);
            expect(
              adaptedExplanation!.graph.nodes.first.referencedEntityIds,
              contains(adaptedRecommendation.recommendationId),
              reason: fixture.name,
            );
            expect(
              adaptedExplanation.explanationId,
              endsWith(adaptedRecommendation.recommendationId),
              reason: fixture.name,
            );
            expect(
              evaluation.candidate.blockReasons,
              isEmpty,
              reason: fixture.name,
            );
            expect(
              evaluation.runtimeAllowlist.source,
              FinancialRuntimeRecommendationSource.intelligenceAllowlist,
              reason: fixture.name,
            );
            expect(
              evaluation.runtimeAllowlist.recommendation,
              same(adaptedRecommendation),
              reason: fixture.name,
            );
            expect(
              evaluation.runtimeAllowlist.explanation,
              same(adaptedExplanation),
              reason: fixture.name,
            );
          } else {
            expect(
              evaluation.candidate.adaptedRecommendation,
              isNull,
              reason: fixture.name,
            );
            expect(
              evaluation.candidate.adaptedExplanation,
              isNull,
              reason: fixture.name,
            );
            expect(
              evaluation.candidate.blockReasons,
              contains(fixture.expectedBlockReason),
              reason: fixture.name,
            );
            expect(
              evaluation.runtimeAllowlist.source,
              FinancialRuntimeRecommendationSource.legacy,
              reason: fixture.name,
            );
            expect(
              evaluation.runtimeAllowlist.recommendation,
              same(evaluation.legacyRecommendation),
              reason: fixture.name,
            );
            expect(
              evaluation.runtimeAllowlist.explanation,
              isNull,
              reason: fixture.name,
            );
          }

          expect(
            evaluation.legacySelection.source,
            FinancialRuntimeRecommendationSource.legacy,
            reason: fixture.name,
          );
          expect(
            evaluation.legacySelection.recommendation,
            same(evaluation.legacyRecommendation),
            reason: fixture.name,
          );
          expect(
            evaluation.legacySelection.explanation,
            isNull,
            reason: fixture.name,
          );
          expect(
            evaluation.shadowOnlySelection.source,
            FinancialRuntimeRecommendationSource.legacy,
            reason: fixture.name,
          );
          expect(
            evaluation.shadowOnlySelection.recommendation,
            same(evaluation.legacyRecommendation),
            reason: fixture.name,
          );
          expect(
            evaluation.shadowOnlySelection.explanation,
            isNull,
            reason: fixture.name,
          );
        }
      },
    );

    test('mode regression keeps legacy and allowlist fallback boundaries', () {
      for (final fixture in _fixtures()) {
        final evaluation = _evaluate(
          fixture,
          selectionService: selectionService,
          explanationService: explanationService,
          comparisonService: comparisonService,
          adapter: adapter,
          policy: policy,
        );

        expect(
          evaluation.legacySelection.mode,
          FinancialRuntimeRecommendationMode.legacy,
          reason: fixture.name,
        );
        expect(
          evaluation.legacySelection.source,
          FinancialRuntimeRecommendationSource.legacy,
          reason: fixture.name,
        );
        expect(
          evaluation.legacySelection.recommendation,
          same(evaluation.legacyRecommendation),
          reason: fixture.name,
        );

        expect(
          evaluation.shadowOnlySelection.mode,
          FinancialRuntimeRecommendationMode.shadowOnly,
          reason: fixture.name,
        );
        expect(
          evaluation.shadowOnlySelection.source,
          FinancialRuntimeRecommendationSource.legacy,
          reason: fixture.name,
        );
        expect(
          evaluation.shadowOnlySelection.recommendation,
          same(evaluation.legacyRecommendation),
          reason: fixture.name,
        );
        expect(
          evaluation.shadowOnlySelection.explanation,
          isNull,
          reason: fixture.name,
        );

        expect(
          evaluation.runtimeAllowlist.mode,
          FinancialRuntimeRecommendationMode.intelligenceAllowlist,
          reason: fixture.name,
        );
        if (fixture.isCandidateEligible && fixture.isAllowlistedByPolicy) {
          expect(
            evaluation.runtimeAllowlist.source,
            FinancialRuntimeRecommendationSource.intelligenceAllowlist,
            reason: fixture.name,
          );
          expect(
            evaluation.runtimeAllowlist.recommendation,
            same(evaluation.candidate.adaptedRecommendation),
            reason: fixture.name,
          );
          expect(
            evaluation.runtimeAllowlist.explanation,
            same(evaluation.candidate.adaptedExplanation),
            reason: fixture.name,
          );
          expect(
            evaluation.runtimeAllowlist.comparison,
            same(evaluation.comparison),
            reason: fixture.name,
          );
        } else {
          expect(
            evaluation.runtimeAllowlist.source,
            FinancialRuntimeRecommendationSource.legacy,
            reason: fixture.name,
          );
          expect(
            evaluation.runtimeAllowlist.recommendation,
            same(evaluation.legacyRecommendation),
            reason: fixture.name,
          );
          expect(
            evaluation.runtimeAllowlist.explanation,
            isNull,
            reason: fixture.name,
          );
          expect(
            evaluation.runtimeAllowlist.comparison,
            isNull,
            reason: fixture.name,
          );
        }
      }
    });
  });
}

List<_RuntimeAdapterFixture> _fixtures() {
  return const [
    _RuntimeAdapterFixture(
      name: 'ordinary spending',
      legacyType: FinancialDecisionOptionType.reviewExpenseStructure,
      shadowTypes: [
        FinancialIntelligenceRecommendationType.reviewOrdinarySpendingStructure,
      ],
      expectedSelectedType: FinancialIntelligenceDecisionOptionType
          .reviewOrdinarySpendingStructure,
      expectedRejectedTypes: [],
      expectedConflictLevel: FinancialRecommendationConflictLevel.aligned,
      expectedFlags: [
        FinancialRecommendationComparisonFlag.legacyRecommendationPresent,
        FinancialRecommendationComparisonFlag.shadowDiagnosticsPresent,
        FinancialRecommendationComparisonFlag.directMatch,
      ],
      isCandidateEligible: true,
      isAllowlistedByPolicy: true,
      expectedBlockReason: null,
      hasPositiveSignals: false,
      hasContextWarnings: false,
      hasCoverageWarnings: false,
    ),
    _RuntimeAdapterFixture(
      name: 'reducible spending',
      legacyType: FinancialDecisionOptionType.reduceDiscretionarySpending,
      shadowTypes: [
        FinancialIntelligenceRecommendationType.reduceReducibleSpending,
      ],
      expectedSelectedType:
          FinancialIntelligenceDecisionOptionType.reduceReducibleSpending,
      expectedRejectedTypes: [],
      expectedConflictLevel: FinancialRecommendationConflictLevel.aligned,
      expectedFlags: [
        FinancialRecommendationComparisonFlag.legacyRecommendationPresent,
        FinancialRecommendationComparisonFlag.shadowDiagnosticsPresent,
        FinancialRecommendationComparisonFlag.directMatch,
      ],
      isCandidateEligible: true,
      isAllowlistedByPolicy: true,
      expectedBlockReason: null,
      hasPositiveSignals: false,
      hasContextWarnings: false,
      hasCoverageWarnings: false,
    ),
    _RuntimeAdapterFixture(
      name: 'discretionary spending',
      legacyType: FinancialDecisionOptionType.deferOptionalSpending,
      shadowTypes: [
        FinancialIntelligenceRecommendationType
            .deferOrReduceDiscretionarySpending,
      ],
      expectedSelectedType: FinancialIntelligenceDecisionOptionType
          .deferOrReduceDiscretionarySpending,
      expectedRejectedTypes: [],
      expectedConflictLevel: FinancialRecommendationConflictLevel.aligned,
      expectedFlags: [
        FinancialRecommendationComparisonFlag.legacyRecommendationPresent,
        FinancialRecommendationComparisonFlag.shadowDiagnosticsPresent,
        FinancialRecommendationComparisonFlag.directMatch,
      ],
      isCandidateEligible: true,
      isAllowlistedByPolicy: true,
      expectedBlockReason: null,
      hasPositiveSignals: false,
      hasContextWarnings: false,
      hasCoverageWarnings: false,
    ),
    _RuntimeAdapterFixture(
      name: 'category coverage',
      legacyType: FinancialDecisionOptionType.improveCategorization,
      shadowTypes: [
        FinancialIntelligenceRecommendationType.improveCategoryCoverage,
      ],
      expectedSelectedType:
          FinancialIntelligenceDecisionOptionType.improveCategoryCoverage,
      expectedRejectedTypes: [],
      expectedConflictLevel: FinancialRecommendationConflictLevel.aligned,
      expectedFlags: [
        FinancialRecommendationComparisonFlag.legacyRecommendationPresent,
        FinancialRecommendationComparisonFlag.shadowDiagnosticsPresent,
        FinancialRecommendationComparisonFlag.coverageWarningPresent,
        FinancialRecommendationComparisonFlag.directMatch,
      ],
      isCandidateEligible: true,
      isAllowlistedByPolicy: true,
      expectedBlockReason: null,
      hasPositiveSignals: false,
      hasContextWarnings: false,
      hasCoverageWarnings: true,
    ),
    _RuntimeAdapterFixture(
      name: 'mandatory spending',
      legacyType: FinancialDecisionOptionType.optimizeEssentialExpenses,
      shadowTypes: [
        FinancialIntelligenceRecommendationType.reviewMandatoryCosts,
      ],
      expectedSelectedType:
          FinancialIntelligenceDecisionOptionType.reviewMandatoryCosts,
      expectedRejectedTypes: [],
      expectedConflictLevel: FinancialRecommendationConflictLevel.aligned,
      expectedFlags: [
        FinancialRecommendationComparisonFlag.legacyRecommendationPresent,
        FinancialRecommendationComparisonFlag.shadowDiagnosticsPresent,
        FinancialRecommendationComparisonFlag.directMatch,
      ],
      isCandidateEligible: false,
      isAllowlistedByPolicy: false,
      expectedBlockReason: 'unsupportedIntelligenceOption',
      hasPositiveSignals: false,
      hasContextWarnings: false,
      hasCoverageWarnings: false,
    ),
    _RuntimeAdapterFixture(
      name: 'asset building',
      legacyType: FinancialDecisionOptionType.buildSavingsCapacity,
      shadowTypes: [
        FinancialIntelligenceRecommendationType.maintainAssetBuildingMomentum,
      ],
      expectedSelectedType:
          FinancialIntelligenceDecisionOptionType.maintainAssetBuildingMomentum,
      expectedRejectedTypes: [],
      expectedConflictLevel:
          FinancialRecommendationConflictLevel.partialOverlap,
      expectedFlags: [
        FinancialRecommendationComparisonFlag.legacyRecommendationPresent,
        FinancialRecommendationComparisonFlag.shadowDiagnosticsPresent,
        FinancialRecommendationComparisonFlag.positiveSignalPresent,
        FinancialRecommendationComparisonFlag.partialMatch,
      ],
      isCandidateEligible: false,
      isAllowlistedByPolicy: false,
      expectedBlockReason: 'unsupportedIntelligenceOption',
      hasPositiveSignals: true,
      hasContextWarnings: false,
      hasCoverageWarnings: false,
    ),
    _RuntimeAdapterFixture(
      name: 'debt reduction',
      legacyType: FinancialDecisionOptionType.reduceDiscretionarySpending,
      shadowTypes: [
        FinancialIntelligenceRecommendationType.maintainDebtReductionMomentum,
      ],
      expectedSelectedType:
          FinancialIntelligenceDecisionOptionType.maintainDebtReductionMomentum,
      expectedRejectedTypes: [],
      expectedConflictLevel: FinancialRecommendationConflictLevel.divergent,
      expectedFlags: [
        FinancialRecommendationComparisonFlag.legacyRecommendationPresent,
        FinancialRecommendationComparisonFlag.shadowDiagnosticsPresent,
        FinancialRecommendationComparisonFlag.positiveSignalPresent,
        FinancialRecommendationComparisonFlag.divergentMatch,
      ],
      isCandidateEligible: false,
      isAllowlistedByPolicy: false,
      expectedBlockReason: 'unsupportedIntelligenceOption',
      hasPositiveSignals: true,
      hasContextWarnings: false,
      hasCoverageWarnings: false,
    ),
    _RuntimeAdapterFixture(
      name: 'credit card payment',
      legacyType: FinancialDecisionOptionType.reduceDiscretionarySpending,
      shadowTypes: [
        FinancialIntelligenceRecommendationType.maintainDebtReductionMomentum,
        FinancialIntelligenceRecommendationType.reviewTransactionContext,
      ],
      expectedSelectedType:
          FinancialIntelligenceDecisionOptionType.reviewTransactionContext,
      expectedRejectedTypes: [
        FinancialIntelligenceDecisionOptionType.maintainDebtReductionMomentum,
      ],
      expectedConflictLevel: FinancialRecommendationConflictLevel.divergent,
      expectedFlags: [
        FinancialRecommendationComparisonFlag.legacyRecommendationPresent,
        FinancialRecommendationComparisonFlag.shadowDiagnosticsPresent,
        FinancialRecommendationComparisonFlag.positiveSignalPresent,
        FinancialRecommendationComparisonFlag.contextWarningPresent,
        FinancialRecommendationComparisonFlag.divergentMatch,
      ],
      isCandidateEligible: false,
      isAllowlistedByPolicy: false,
      expectedBlockReason: 'unsupportedIntelligenceOption',
      hasPositiveSignals: true,
      hasContextWarnings: true,
      hasCoverageWarnings: false,
    ),
    _RuntimeAdapterFixture(
      name: 'cash withdrawal',
      legacyType: FinancialDecisionOptionType.reduceDiscretionarySpending,
      shadowTypes: [
        FinancialIntelligenceRecommendationType.reviewTransactionContext,
      ],
      expectedSelectedType:
          FinancialIntelligenceDecisionOptionType.reviewTransactionContext,
      expectedRejectedTypes: [],
      expectedConflictLevel: FinancialRecommendationConflictLevel.divergent,
      expectedFlags: [
        FinancialRecommendationComparisonFlag.legacyRecommendationPresent,
        FinancialRecommendationComparisonFlag.shadowDiagnosticsPresent,
        FinancialRecommendationComparisonFlag.contextWarningPresent,
        FinancialRecommendationComparisonFlag.divergentMatch,
      ],
      isCandidateEligible: false,
      isAllowlistedByPolicy: false,
      expectedBlockReason: 'unsupportedIntelligenceOption',
      hasPositiveSignals: false,
      hasContextWarnings: true,
      hasCoverageWarnings: false,
    ),
    _RuntimeAdapterFixture(
      name: 'adjustment',
      legacyType: FinancialDecisionOptionType.reduceDiscretionarySpending,
      shadowTypes: [
        FinancialIntelligenceRecommendationType.reviewTransactionContext,
        FinancialIntelligenceRecommendationType.improveCategoryCoverage,
      ],
      expectedSelectedType:
          FinancialIntelligenceDecisionOptionType.reviewTransactionContext,
      expectedRejectedTypes: [
        FinancialIntelligenceDecisionOptionType.improveCategoryCoverage,
      ],
      expectedConflictLevel: FinancialRecommendationConflictLevel.divergent,
      expectedFlags: [
        FinancialRecommendationComparisonFlag.legacyRecommendationPresent,
        FinancialRecommendationComparisonFlag.shadowDiagnosticsPresent,
        FinancialRecommendationComparisonFlag.contextWarningPresent,
        FinancialRecommendationComparisonFlag.coverageWarningPresent,
        FinancialRecommendationComparisonFlag.divergentMatch,
      ],
      isCandidateEligible: false,
      isAllowlistedByPolicy: false,
      expectedBlockReason: 'unsupportedIntelligenceOption',
      hasPositiveSignals: false,
      hasContextWarnings: true,
      hasCoverageWarnings: true,
    ),
    _RuntimeAdapterFixture(
      name: 'unresolved category',
      legacyType: FinancialDecisionOptionType.reduceDiscretionarySpending,
      shadowTypes: [
        FinancialIntelligenceRecommendationType.improveCategoryCoverage,
      ],
      expectedSelectedType:
          FinancialIntelligenceDecisionOptionType.improveCategoryCoverage,
      expectedRejectedTypes: [],
      expectedConflictLevel: FinancialRecommendationConflictLevel.divergent,
      expectedFlags: [
        FinancialRecommendationComparisonFlag.legacyRecommendationPresent,
        FinancialRecommendationComparisonFlag.shadowDiagnosticsPresent,
        FinancialRecommendationComparisonFlag.coverageWarningPresent,
        FinancialRecommendationComparisonFlag.divergentMatch,
      ],
      isCandidateEligible: false,
      isAllowlistedByPolicy: false,
      expectedBlockReason: 'comparisonNotAligned',
      hasPositiveSignals: false,
      hasContextWarnings: false,
      hasCoverageWarnings: true,
    ),
    _RuntimeAdapterFixture(
      name: 'context-required-heavy month',
      legacyType: FinancialDecisionOptionType.reduceDiscretionarySpending,
      shadowTypes: [
        FinancialIntelligenceRecommendationType.maintainDebtReductionMomentum,
        FinancialIntelligenceRecommendationType.reviewTransactionContext,
        FinancialIntelligenceRecommendationType.improveCategoryCoverage,
      ],
      expectedSelectedType:
          FinancialIntelligenceDecisionOptionType.reviewTransactionContext,
      expectedRejectedTypes: [
        FinancialIntelligenceDecisionOptionType.maintainDebtReductionMomentum,
        FinancialIntelligenceDecisionOptionType.improveCategoryCoverage,
      ],
      expectedConflictLevel: FinancialRecommendationConflictLevel.divergent,
      expectedFlags: [
        FinancialRecommendationComparisonFlag.legacyRecommendationPresent,
        FinancialRecommendationComparisonFlag.shadowDiagnosticsPresent,
        FinancialRecommendationComparisonFlag.positiveSignalPresent,
        FinancialRecommendationComparisonFlag.contextWarningPresent,
        FinancialRecommendationComparisonFlag.coverageWarningPresent,
        FinancialRecommendationComparisonFlag.divergentMatch,
      ],
      isCandidateEligible: false,
      isAllowlistedByPolicy: false,
      expectedBlockReason: 'unsupportedIntelligenceOption',
      hasPositiveSignals: true,
      hasContextWarnings: true,
      hasCoverageWarnings: true,
    ),
  ];
}

_RuntimeAdapterEvaluation _evaluate(
  _RuntimeAdapterFixture fixture, {
  required FinancialIntelligenceRecommendationSelectionService selectionService,
  required FinancialIntelligenceRecommendationExplanationService
  explanationService,
  required FinancialRecommendationComparisonService comparisonService,
  required FinancialIntelligenceRuntimeRecommendationAdapter adapter,
  required FinancialRuntimeRecommendationPolicy policy,
}) {
  final legacyRecommendation = buildTestFinancialRecommendation(
    fixture.legacyType,
  );
  final decisionOptions = [
    for (final type in fixture.selectedAndRejectedTypes) _decisionOption(type),
  ];
  final selection = selectionService.select(
    FinancialIntelligenceDecisionOptionsSnapshot(options: decisionOptions),
  );
  final problems = FinancialIntelligenceProblemsSnapshot(
    problems: [
      for (final type in fixture.selectedAndRejectedTypes)
        _problemForType(type),
    ],
  );
  final parity = _paritySnapshot(fixture.selectedAndRejectedTypes);
  final explanation = explanationService.build(
    selection: selection,
    problems: problems,
    parity: parity,
  );
  final shadowDiagnostics =
      FinancialIntelligenceRecommendationDiagnosticsSnapshot(
        recommendations: [
          for (final type in fixture.shadowTypes) _shadowRecommendation(type),
        ],
      );
  final comparison = comparisonService.build(
    legacyRecommendation: legacyRecommendation,
    shadowDiagnostics: shadowDiagnostics,
  );
  final candidate = adapter.build(
    selection: selection,
    explanation: explanation,
    comparison: comparison,
    generatedAt: _generatedAt,
  );

  return _RuntimeAdapterEvaluation(
    legacyRecommendation: legacyRecommendation,
    selection: selection,
    explanation: explanation,
    comparison: comparison,
    candidate: candidate,
    legacySelection: policy.select(
      mode: FinancialRuntimeRecommendationMode.legacy,
      legacyRecommendation: legacyRecommendation,
      comparison: comparison,
      candidate: candidate,
    ),
    shadowOnlySelection: policy.select(
      mode: FinancialRuntimeRecommendationMode.shadowOnly,
      legacyRecommendation: legacyRecommendation,
      comparison: comparison,
      candidate: candidate,
    ),
    runtimeAllowlist: policy.select(
      mode: FinancialRuntimeRecommendationMode.intelligenceAllowlist,
      legacyRecommendation: legacyRecommendation,
      comparison: comparison,
      candidate: candidate,
    ),
  );
}

FinancialIntelligenceDecisionOption _decisionOption(
  FinancialIntelligenceDecisionOptionType type,
) {
  final parityMetric = _parityMetricFor(type);
  final isPositiveSignal = _isPositiveSignal(type);

  return FinancialIntelligenceDecisionOption(
    optionId: 'financial.intelligence.decisionOption.${type.name}',
    type: type,
    period: _period,
    sourceProblemIds: ['financial.intelligence.problem.${type.name}'],
    sourceProblemTypes: [_problemTypeForOption(type)],
    parityMetric: parityMetric,
    parityStatus: _parityMetricStatusFor(type),
    legacyModelValue: parityMetric == null ? null : _parityValueFor(type),
    intelligenceModelValue: parityMetric == null ? null : _parityValueFor(type),
    isPositiveSignal: isPositiveSignal,
    isWarning:
        !isPositiveSignal &&
        type != FinancialIntelligenceDecisionOptionType.improveCategoryCoverage,
    isDiagnosticsOnly: true,
  );
}

FinancialIntelligenceRecommendation _shadowRecommendation(
  FinancialIntelligenceRecommendationType type,
) {
  final isPositiveSignal =
      type ==
          FinancialIntelligenceRecommendationType
              .maintainAssetBuildingMomentum ||
      type ==
          FinancialIntelligenceRecommendationType.maintainDebtReductionMomentum;

  return FinancialIntelligenceRecommendation(
    recommendationId: 'financial.intelligence.recommendation.${type.name}',
    type: type,
    period: _period,
    sourceProblemIds: ['financial.intelligence.problem.${type.name}'],
    sourceProblemTypes: [_problemTypeForRecommendation(type)],
    isPositiveSignal: isPositiveSignal,
    isWarning:
        !isPositiveSignal &&
        type != FinancialIntelligenceRecommendationType.improveCategoryCoverage,
    isDiagnosticsOnly: true,
  );
}

FinancialIntelligenceProblemType _problemTypeForRecommendation(
  FinancialIntelligenceRecommendationType type,
) {
  return switch (type) {
    FinancialIntelligenceRecommendationType.reviewOrdinarySpendingStructure =>
      FinancialIntelligenceProblemType.ordinarySpendingPressure,
    FinancialIntelligenceRecommendationType.reviewMandatoryCosts =>
      FinancialIntelligenceProblemType.mandatoryCostPressure,
    FinancialIntelligenceRecommendationType.reduceReducibleSpending =>
      FinancialIntelligenceProblemType.reducibleSpendingPressure,
    FinancialIntelligenceRecommendationType
        .deferOrReduceDiscretionarySpending =>
      FinancialIntelligenceProblemType.discretionarySpendingPressure,
    FinancialIntelligenceRecommendationType.maintainAssetBuildingMomentum =>
      FinancialIntelligenceProblemType.positiveAssetBuildingSignal,
    FinancialIntelligenceRecommendationType.maintainDebtReductionMomentum =>
      FinancialIntelligenceProblemType.debtReductionSignal,
    FinancialIntelligenceRecommendationType.reviewTransactionContext =>
      FinancialIntelligenceProblemType.transactionContextRequired,
    FinancialIntelligenceRecommendationType.improveCategoryCoverage =>
      FinancialIntelligenceProblemType.classificationCoverageGap,
  };
}

FinancialIntelligenceProblem _problemForType(
  FinancialIntelligenceDecisionOptionType type,
) {
  final isPositiveSignal = _isPositiveSignal(type);

  return FinancialIntelligenceProblem(
    problemId: 'financial.intelligence.problem.${type.name}',
    type: _problemTypeForOption(type),
    period: _period,
    severity: isPositiveSignal
        ? FinancialProblemSeverity.low
        : FinancialProblemSeverity.medium,
    impact: isPositiveSignal
        ? FinancialProblemImpact.savingsCapacity
        : FinancialProblemImpact.spendingFlexibility,
    sourceDeviationIds: ['financial.intelligence.deviation.${type.name}'],
    sourceDeviationTypes: const [],
    isPositiveSignal: isPositiveSignal,
    isWarning: !isPositiveSignal,
    isDiagnosticsOnly: true,
  );
}

FinancialIntelligenceModelParitySnapshot _paritySnapshot(
  List<FinancialIntelligenceDecisionOptionType> types,
) {
  final metricResults = <FinancialIntelligenceModelParityMetricResult>[
    for (final type in types)
      if (_parityMetricFor(type) case final metric?)
        _parityResult(
          metric,
          status:
              _parityMetricStatusFor(type) ??
              FinancialIntelligenceModelParityStatus.equivalent,
          legacyValue: _parityValueFor(type),
          intelligenceValue: _parityValueFor(type),
        ),
  ];

  return FinancialIntelligenceModelParitySnapshot(
    legacyModelValues: {
      for (final result in metricResults) result.metric: result.legacyValue,
    },
    intelligenceModelValues: {
      for (final result in metricResults)
        result.metric: result.intelligenceValue,
    },
    metricResults: metricResults,
    matchedMetrics: metricResults,
    missingMetrics: metricResults
        .where(
          (result) =>
              result.status ==
              FinancialIntelligenceModelParityStatus.unsupported,
        )
        .toList(growable: false),
    intentionallyDivergentMetrics: metricResults
        .where(
          (result) =>
              result.status ==
              FinancialIntelligenceModelParityStatus.intentionallyDifferent,
        )
        .toList(growable: false),
  );
}

FinancialIntelligenceModelParityMetricResult _parityResult(
  FinancialIntelligenceModelParityMetric metric, {
  required FinancialIntelligenceModelParityStatus status,
  required double? legacyValue,
  required double? intelligenceValue,
}) {
  return FinancialIntelligenceModelParityMetricResult(
    metric: metric,
    status: status,
    legacyValue: legacyValue,
    intelligenceValue: intelligenceValue,
  );
}

FinancialIntelligenceProblemType _problemTypeForOption(
  FinancialIntelligenceDecisionOptionType type,
) {
  return switch (type) {
    FinancialIntelligenceDecisionOptionType.reviewOrdinarySpendingStructure =>
      FinancialIntelligenceProblemType.ordinarySpendingPressure,
    FinancialIntelligenceDecisionOptionType.reduceReducibleSpending =>
      FinancialIntelligenceProblemType.reducibleSpendingPressure,
    FinancialIntelligenceDecisionOptionType
        .deferOrReduceDiscretionarySpending =>
      FinancialIntelligenceProblemType.discretionarySpendingPressure,
    FinancialIntelligenceDecisionOptionType.reviewMandatoryCosts =>
      FinancialIntelligenceProblemType.mandatoryCostPressure,
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

FinancialIntelligenceModelParityMetric? _parityMetricFor(
  FinancialIntelligenceDecisionOptionType type,
) {
  return switch (type) {
    FinancialIntelligenceDecisionOptionType.reviewOrdinarySpendingStructure =>
      FinancialIntelligenceModelParityMetric.ordinarySpending,
    FinancialIntelligenceDecisionOptionType.reduceReducibleSpending =>
      FinancialIntelligenceModelParityMetric.reducibleSpending,
    FinancialIntelligenceDecisionOptionType
        .deferOrReduceDiscretionarySpending =>
      FinancialIntelligenceModelParityMetric.discretionarySpending,
    FinancialIntelligenceDecisionOptionType.reviewMandatoryCosts =>
      FinancialIntelligenceModelParityMetric.mandatorySpending,
    FinancialIntelligenceDecisionOptionType.maintainAssetBuildingMomentum =>
      FinancialIntelligenceModelParityMetric.assetBuilding,
    FinancialIntelligenceDecisionOptionType.maintainDebtReductionMomentum =>
      FinancialIntelligenceModelParityMetric.debtReduction,
    FinancialIntelligenceDecisionOptionType.reviewTransactionContext => null,
    FinancialIntelligenceDecisionOptionType.improveCategoryCoverage => null,
  };
}

FinancialIntelligenceModelParityStatus? _parityMetricStatusFor(
  FinancialIntelligenceDecisionOptionType type,
) {
  return switch (type) {
    FinancialIntelligenceDecisionOptionType.reviewOrdinarySpendingStructure =>
      FinancialIntelligenceModelParityStatus.equivalent,
    FinancialIntelligenceDecisionOptionType.reduceReducibleSpending =>
      FinancialIntelligenceModelParityStatus.equivalent,
    FinancialIntelligenceDecisionOptionType
        .deferOrReduceDiscretionarySpending =>
      FinancialIntelligenceModelParityStatus.equivalent,
    FinancialIntelligenceDecisionOptionType.reviewMandatoryCosts =>
      FinancialIntelligenceModelParityStatus.equivalent,
    FinancialIntelligenceDecisionOptionType.maintainAssetBuildingMomentum =>
      FinancialIntelligenceModelParityStatus.unsupported,
    FinancialIntelligenceDecisionOptionType.maintainDebtReductionMomentum =>
      FinancialIntelligenceModelParityStatus.unsupported,
    FinancialIntelligenceDecisionOptionType.reviewTransactionContext => null,
    FinancialIntelligenceDecisionOptionType.improveCategoryCoverage => null,
  };
}

double? _parityValueFor(FinancialIntelligenceDecisionOptionType type) {
  return switch (type) {
    FinancialIntelligenceDecisionOptionType.reviewOrdinarySpendingStructure =>
      100,
    FinancialIntelligenceDecisionOptionType.reduceReducibleSpending => 80,
    FinancialIntelligenceDecisionOptionType
        .deferOrReduceDiscretionarySpending =>
      60,
    FinancialIntelligenceDecisionOptionType.reviewMandatoryCosts => 120,
    FinancialIntelligenceDecisionOptionType.maintainAssetBuildingMomentum =>
      200,
    FinancialIntelligenceDecisionOptionType.maintainDebtReductionMomentum =>
      150,
    FinancialIntelligenceDecisionOptionType.reviewTransactionContext => null,
    FinancialIntelligenceDecisionOptionType.improveCategoryCoverage => null,
  };
}

bool _isPositiveSignal(FinancialIntelligenceDecisionOptionType type) {
  return switch (type) {
    FinancialIntelligenceDecisionOptionType.maintainAssetBuildingMomentum ||
    FinancialIntelligenceDecisionOptionType.maintainDebtReductionMomentum =>
      true,
    _ => false,
  };
}

final class _RuntimeAdapterFixture {
  const _RuntimeAdapterFixture({
    required this.name,
    required this.legacyType,
    required this.shadowTypes,
    required this.expectedSelectedType,
    required this.expectedRejectedTypes,
    required this.expectedConflictLevel,
    required this.expectedFlags,
    required this.isCandidateEligible,
    required this.isAllowlistedByPolicy,
    required this.expectedBlockReason,
    required this.hasPositiveSignals,
    required this.hasContextWarnings,
    required this.hasCoverageWarnings,
  });

  final String name;
  final FinancialDecisionOptionType legacyType;
  final List<FinancialIntelligenceRecommendationType> shadowTypes;
  final FinancialIntelligenceDecisionOptionType expectedSelectedType;
  final List<FinancialIntelligenceDecisionOptionType> expectedRejectedTypes;
  final FinancialRecommendationConflictLevel expectedConflictLevel;
  final List<FinancialRecommendationComparisonFlag> expectedFlags;
  final bool isCandidateEligible;
  final bool isAllowlistedByPolicy;
  final String? expectedBlockReason;
  final bool hasPositiveSignals;
  final bool hasContextWarnings;
  final bool hasCoverageWarnings;

  List<FinancialIntelligenceDecisionOptionType> get selectedAndRejectedTypes {
    return [expectedSelectedType, ...expectedRejectedTypes];
  }
}

final class _RuntimeAdapterEvaluation {
  const _RuntimeAdapterEvaluation({
    required this.legacyRecommendation,
    required this.selection,
    required this.explanation,
    required this.comparison,
    required this.candidate,
    required this.legacySelection,
    required this.shadowOnlySelection,
    required this.runtimeAllowlist,
  });

  final dynamic legacyRecommendation;
  final FinancialIntelligenceRecommendationSelectionSnapshot selection;
  final FinancialIntelligenceRecommendationExplanationSnapshot explanation;
  final FinancialRecommendationComparisonReadModel comparison;
  final dynamic candidate;
  final FinancialRuntimeRecommendationSelection legacySelection;
  final FinancialRuntimeRecommendationSelection shadowOnlySelection;
  final FinancialRuntimeRecommendationSelection runtimeAllowlist;
}

final _generatedAt = DateTime.utc(2035, 6, 15);
final _period = FinancialModelPeriod(
  start: DateTime.utc(2035, 6),
  end: DateTime.utc(2035, 7),
);
