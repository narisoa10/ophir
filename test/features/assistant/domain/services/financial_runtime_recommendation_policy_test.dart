import 'package:flutter_test/flutter_test.dart';
import 'package:ophir/features/assistant/domain/entities/financial_decision_option_type.dart';
import 'package:ophir/features/assistant/domain/entities/financial_intelligence_recommendation_type.dart';
import 'package:ophir/features/assistant/domain/entities/financial_intelligence_runtime_recommendation_candidate.dart';
import 'package:ophir/features/assistant/domain/entities/financial_recommendation.dart';
import 'package:ophir/features/assistant/domain/entities/financial_recommendation_comparison_flag.dart';
import 'package:ophir/features/assistant/domain/entities/financial_recommendation_comparison_read_model.dart';
import 'package:ophir/features/assistant/domain/entities/financial_recommendation_conflict_level.dart';
import 'package:ophir/features/assistant/domain/entities/financial_runtime_recommendation_mode.dart';
import 'package:ophir/features/assistant/domain/entities/financial_runtime_recommendation_source.dart';
import 'package:ophir/features/assistant/domain/services/financial_runtime_recommendation_policy.dart';

import '../../helpers/financial_recommendation_test_helpers.dart';

void main() {
  const policy = FinancialRuntimeRecommendationPolicy();

  group('FinancialRuntimeRecommendationPolicy', () {
    test('legacy mode always uses legacy recommendation', () {
      final legacy = buildTestFinancialRecommendation(
        FinancialDecisionOptionType.reduceDiscretionarySpending,
      );
      final comparison = _alignedComparison(
        legacyType: FinancialDecisionOptionType.reduceDiscretionarySpending,
        shadowTypes: const [
          FinancialIntelligenceRecommendationType.reduceReducibleSpending,
        ],
      );

      final selection = policy.select(
        mode: FinancialRuntimeRecommendationMode.legacy,
        legacyRecommendation: legacy,
        comparison: comparison,
      );

      expect(selection.source, FinancialRuntimeRecommendationSource.legacy);
      expect(selection.recommendation, same(legacy));
      expect(selection.usesIntelligenceRuntime, isFalse);
    });

    test('shadowOnly mode keeps diagnostics out of runtime', () {
      final legacy = buildTestFinancialRecommendation(
        FinancialDecisionOptionType.reviewExpenseStructure,
      );

      final selection = policy.select(
        mode: FinancialRuntimeRecommendationMode.shadowOnly,
        legacyRecommendation: legacy,
        comparison: _alignedComparison(
          legacyType: FinancialDecisionOptionType.reviewExpenseStructure,
          shadowTypes: const [
            FinancialIntelligenceRecommendationType
                .reviewOrdinarySpendingStructure,
          ],
        ),
      );

      expect(selection.source, FinancialRuntimeRecommendationSource.legacy);
      expect(selection.recommendation, same(legacy));
    });

    test('intelligenceAllowlist switches only aligned allowlist cases', () {
      final cases = [
        _AllowlistCase(
          legacyType: FinancialDecisionOptionType.reviewExpenseStructure,
          shadowTypes: const [
            FinancialIntelligenceRecommendationType
                .reviewOrdinarySpendingStructure,
          ],
        ),
        _AllowlistCase(
          legacyType: FinancialDecisionOptionType.reduceDiscretionarySpending,
          shadowTypes: const [
            FinancialIntelligenceRecommendationType.reduceReducibleSpending,
          ],
        ),
        _AllowlistCase(
          legacyType: FinancialDecisionOptionType.deferOptionalSpending,
          shadowTypes: const [
            FinancialIntelligenceRecommendationType
                .deferOrReduceDiscretionarySpending,
          ],
        ),
        _AllowlistCase(
          legacyType: FinancialDecisionOptionType.improveCategorization,
          shadowTypes: const [
            FinancialIntelligenceRecommendationType.improveCategoryCoverage,
          ],
        ),
      ];

      for (final testCase in cases) {
        final legacy = buildTestFinancialRecommendation(testCase.legacyType);
        final adapted = buildTestFinancialRecommendation(testCase.legacyType);
        final candidate = _eligibleCandidate(adapted);
        final comparison = _alignedComparison(
          legacyType: testCase.legacyType,
          shadowTypes: testCase.shadowTypes,
        );

        final selection = policy.select(
          mode: FinancialRuntimeRecommendationMode.intelligenceAllowlist,
          legacyRecommendation: legacy,
          comparison: comparison,
          candidate: candidate,
        );

        expect(
          selection.source,
          FinancialRuntimeRecommendationSource.intelligenceAllowlist,
          reason: testCase.legacyType.name,
        );
        expect(selection.recommendation, same(adapted));
        expect(selection.explanation, same(candidate.adaptedExplanation));
        expect(selection.comparison, same(comparison));
        expect(selection.usesIntelligenceRuntime, isTrue);
      }
    });

    test('any warning flag returns legacy', () {
      final legacy = buildTestFinancialRecommendation(
        FinancialDecisionOptionType.reduceDiscretionarySpending,
      );
      final adapted = buildTestFinancialRecommendation(
        FinancialDecisionOptionType.reduceDiscretionarySpending,
      );

      final selection = policy.select(
        mode: FinancialRuntimeRecommendationMode.intelligenceAllowlist,
        legacyRecommendation: legacy,
        comparison: _alignedComparison(
          legacyType: FinancialDecisionOptionType.reduceDiscretionarySpending,
          shadowTypes: const [
            FinancialIntelligenceRecommendationType.reduceReducibleSpending,
          ],
          flags: const [
            FinancialRecommendationComparisonFlag.contextWarningPresent,
          ],
        ),
        candidate: _eligibleCandidate(adapted),
      );

      expect(selection.source, FinancialRuntimeRecommendationSource.legacy);
    });

    test('partialOverlap returns legacy', () {
      final legacy = buildTestFinancialRecommendation(
        FinancialDecisionOptionType.buildSavingsCapacity,
      );

      final selection = policy.select(
        mode: FinancialRuntimeRecommendationMode.intelligenceAllowlist,
        legacyRecommendation: legacy,
        comparison: buildTestRecommendationComparison(
          legacyType: FinancialDecisionOptionType.buildSavingsCapacity,
          shadowTypes: const [
            FinancialIntelligenceRecommendationType
                .maintainAssetBuildingMomentum,
          ],
          conflictLevel: FinancialRecommendationConflictLevel.partialOverlap,
        ),
      );

      expect(selection.source, FinancialRuntimeRecommendationSource.legacy);
    });

    test('divergent returns legacy', () {
      final legacy = buildTestFinancialRecommendation(
        FinancialDecisionOptionType.reduceDiscretionarySpending,
      );

      final selection = policy.select(
        mode: FinancialRuntimeRecommendationMode.intelligenceAllowlist,
        legacyRecommendation: legacy,
        comparison: buildTestRecommendationComparison(
          legacyType: FinancialDecisionOptionType.reduceDiscretionarySpending,
          shadowTypes: const [
            FinancialIntelligenceRecommendationType
                .maintainDebtReductionMomentum,
          ],
          conflictLevel: FinancialRecommendationConflictLevel.divergent,
        ),
      );

      expect(selection.source, FinancialRuntimeRecommendationSource.legacy);
    });

    test('shadowOnly conflict returns legacy', () {
      final selection = policy.select(
        mode: FinancialRuntimeRecommendationMode.intelligenceAllowlist,
        legacyRecommendation: null,
        comparison: buildTestRecommendationComparison(
          legacyType: null,
          shadowTypes: const [
            FinancialIntelligenceRecommendationType.reduceReducibleSpending,
          ],
          conflictLevel: FinancialRecommendationConflictLevel.shadowOnly,
        ),
      );

      expect(selection.source, FinancialRuntimeRecommendationSource.legacy);
      expect(selection.recommendation, isNull);
    });

    test('positive signal returns legacy', () {
      final legacy = buildTestFinancialRecommendation(
        FinancialDecisionOptionType.reduceDiscretionarySpending,
      );

      final selection = policy.select(
        mode: FinancialRuntimeRecommendationMode.intelligenceAllowlist,
        legacyRecommendation: legacy,
        comparison: _alignedComparison(
          legacyType: FinancialDecisionOptionType.reduceDiscretionarySpending,
          shadowTypes: const [
            FinancialIntelligenceRecommendationType.reduceReducibleSpending,
          ],
          hasPositiveSignals: true,
        ),
      );

      expect(selection.source, FinancialRuntimeRecommendationSource.legacy);
    });

    test('context warning returns legacy', () {
      final legacy = buildTestFinancialRecommendation(
        FinancialDecisionOptionType.reduceDiscretionarySpending,
      );

      final selection = policy.select(
        mode: FinancialRuntimeRecommendationMode.intelligenceAllowlist,
        legacyRecommendation: legacy,
        comparison: _alignedComparison(
          legacyType: FinancialDecisionOptionType.reduceDiscretionarySpending,
          shadowTypes: const [
            FinancialIntelligenceRecommendationType.reduceReducibleSpending,
          ],
          hasContextWarnings: true,
        ),
      );

      expect(selection.source, FinancialRuntimeRecommendationSource.legacy);
    });

    test('coverage warning returns legacy', () {
      final legacy = buildTestFinancialRecommendation(
        FinancialDecisionOptionType.improveCategorization,
      );
      final adapted = buildTestFinancialRecommendation(
        FinancialDecisionOptionType.improveCategorization,
      );

      final selection = policy.select(
        mode: FinancialRuntimeRecommendationMode.intelligenceAllowlist,
        legacyRecommendation: legacy,
        comparison: _alignedComparison(
          legacyType: FinancialDecisionOptionType.improveCategorization,
          shadowTypes: const [
            FinancialIntelligenceRecommendationType.improveCategoryCoverage,
          ],
          hasCoverageWarnings: true,
        ),
        candidate: _eligibleCandidate(adapted),
      );

      expect(
        selection.source,
        FinancialRuntimeRecommendationSource.intelligenceAllowlist,
      );
      expect(selection.recommendation, same(adapted));
    });

    test('coverage warning blocks non coverage allowlist cases', () {
      final legacy = buildTestFinancialRecommendation(
        FinancialDecisionOptionType.reduceDiscretionarySpending,
      );
      final adapted = buildTestFinancialRecommendation(
        FinancialDecisionOptionType.reduceDiscretionarySpending,
      );

      final selection = policy.select(
        mode: FinancialRuntimeRecommendationMode.intelligenceAllowlist,
        legacyRecommendation: legacy,
        comparison: _alignedComparison(
          legacyType: FinancialDecisionOptionType.reduceDiscretionarySpending,
          shadowTypes: const [
            FinancialIntelligenceRecommendationType.reduceReducibleSpending,
          ],
          hasCoverageWarnings: true,
        ),
        candidate: _eligibleCandidate(adapted),
      );

      expect(selection.source, FinancialRuntimeRecommendationSource.legacy);
      expect(selection.recommendation, same(legacy));
    });

    test('blocked candidate returns legacy', () {
      final legacy = buildTestFinancialRecommendation(
        FinancialDecisionOptionType.reduceDiscretionarySpending,
      );
      final adapted = buildTestFinancialRecommendation(
        FinancialDecisionOptionType.reduceDiscretionarySpending,
      );

      final selection = policy.select(
        mode: FinancialRuntimeRecommendationMode.intelligenceAllowlist,
        legacyRecommendation: legacy,
        comparison: _alignedComparison(
          legacyType: FinancialDecisionOptionType.reduceDiscretionarySpending,
          shadowTypes: const [
            FinancialIntelligenceRecommendationType.reduceReducibleSpending,
          ],
        ),
        candidate: _blockedCandidate(adapted),
      );

      expect(selection.source, FinancialRuntimeRecommendationSource.legacy);
      expect(selection.recommendation, same(legacy));
    });

    test('missing recommendation returns legacy', () {
      final selection = policy.select(
        mode: FinancialRuntimeRecommendationMode.intelligenceAllowlist,
        legacyRecommendation: null,
        comparison: _alignedComparison(
          legacyType: FinancialDecisionOptionType.reduceDiscretionarySpending,
          shadowTypes: const [
            FinancialIntelligenceRecommendationType.reduceReducibleSpending,
          ],
        ),
      );

      expect(selection.source, FinancialRuntimeRecommendationSource.legacy);
      expect(selection.recommendation, isNull);
    });

    test('mandatory-only pressure stays legacy', () {
      final legacy = buildTestFinancialRecommendation(
        FinancialDecisionOptionType.optimizeEssentialExpenses,
      );

      final selection = policy.select(
        mode: FinancialRuntimeRecommendationMode.intelligenceAllowlist,
        legacyRecommendation: legacy,
        comparison: _alignedComparison(
          legacyType: FinancialDecisionOptionType.optimizeEssentialExpenses,
          shadowTypes: const [
            FinancialIntelligenceRecommendationType.reviewMandatoryCosts,
          ],
        ),
      );

      expect(selection.source, FinancialRuntimeRecommendationSource.legacy);
    });

    test('rollback legacy mode works independently of comparison', () {
      final legacy = buildTestFinancialRecommendation(
        FinancialDecisionOptionType.reduceDiscretionarySpending,
      );

      final selection = policy.select(
        mode: FinancialRuntimeRecommendationMode.legacy,
        legacyRecommendation: legacy,
        comparison: null,
      );

      expect(selection.source, FinancialRuntimeRecommendationSource.legacy);
      expect(selection.recommendation, same(legacy));
    });
  });
}

FinancialRecommendationComparisonReadModel _alignedComparison({
  required FinancialDecisionOptionType legacyType,
  required List<FinancialIntelligenceRecommendationType> shadowTypes,
  bool hasPositiveSignals = false,
  bool hasContextWarnings = false,
  bool hasCoverageWarnings = false,
  List<FinancialRecommendationComparisonFlag> flags = const [],
}) {
  return buildTestRecommendationComparison(
    legacyType: legacyType,
    shadowTypes: shadowTypes,
    conflictLevel: FinancialRecommendationConflictLevel.aligned,
    hasPositiveSignals: hasPositiveSignals,
    hasContextWarnings: hasContextWarnings,
    hasCoverageWarnings: hasCoverageWarnings,
    flags: flags,
  );
}

final class _AllowlistCase {
  const _AllowlistCase({required this.legacyType, required this.shadowTypes});

  final FinancialDecisionOptionType legacyType;
  final List<FinancialIntelligenceRecommendationType> shadowTypes;
}

FinancialIntelligenceRuntimeRecommendationCandidate _eligibleCandidate(
  FinancialRecommendation recommendation,
) {
  return FinancialIntelligenceRuntimeRecommendationCandidate(
    adaptedRecommendation: recommendation,
    adaptedExplanation: buildTestFinancialExplanation(recommendation),
    sourceIntelligenceOptionIds: const ['intelligence.option'],
    rejectedIntelligenceOptionIds: const [],
    isEligibleForRuntime: true,
    blockReasons: const [],
    confidence: recommendation.confidence,
    priority: recommendation.priority,
    isDiagnosticsOnlySource: true,
  );
}

FinancialIntelligenceRuntimeRecommendationCandidate _blockedCandidate(
  FinancialRecommendation recommendation,
) {
  return FinancialIntelligenceRuntimeRecommendationCandidate(
    adaptedRecommendation: recommendation,
    adaptedExplanation: buildTestFinancialExplanation(recommendation),
    sourceIntelligenceOptionIds: const ['intelligence.option'],
    rejectedIntelligenceOptionIds: const [],
    isEligibleForRuntime: false,
    blockReasons: const ['blocked'],
    confidence: recommendation.confidence,
    priority: recommendation.priority,
    isDiagnosticsOnlySource: true,
  );
}
