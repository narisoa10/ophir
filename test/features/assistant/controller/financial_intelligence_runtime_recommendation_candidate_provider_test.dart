import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ophir/core/errors/result.dart';
import 'package:ophir/features/assistant/controller/financial_intelligence_recommendation_explanation_provider.dart';
import 'package:ophir/features/assistant/controller/financial_intelligence_recommendation_selection_provider.dart';
import 'package:ophir/features/assistant/controller/financial_intelligence_runtime_recommendation_candidate_provider.dart';
import 'package:ophir/features/assistant/controller/financial_recommendation_comparison_provider.dart';
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

import '../helpers/financial_recommendation_test_helpers.dart';

void main() {
  group('financialIntelligenceRuntimeRecommendationCandidateProvider', () {
    test('builds eligible candidate from allowed providers', () async {
      final option = _option(
        FinancialIntelligenceDecisionOptionType.reduceReducibleSpending,
      );
      final selection = _selection(option);
      final container = _container(
        selection: selection,
        explanation: _explanation(selection),
      );
      addTearDown(container.dispose);

      final result = await container.read(
        financialIntelligenceRuntimeRecommendationCandidateProvider.future,
      );
      final candidate = switch (result) {
        Success(:final value) => value,
        Failure() => fail('Expected runtime recommendation candidate'),
      };

      expect(candidate.isEligibleForRuntime, isTrue);
      expect(
        candidate.adaptedRecommendation?.selectedOptionType,
        FinancialDecisionOptionType.reduceDiscretionarySpending,
      );
      expect(candidate.adaptedExplanation, isNotNull);
    });

    test('provider reads only allowed candidate inputs', () {
      final source = File(
        'lib/features/assistant/controller/'
        'financial_intelligence_runtime_recommendation_candidate_provider.dart',
      ).readAsStringSync();

      expect(
        source,
        contains('financialIntelligenceRecommendationSelectionProvider'),
      );
      expect(
        source,
        contains('financialIntelligenceRecommendationExplanationProvider'),
      );
      expect(source, contains('financialRecommendationComparisonProvider'));
      expect(source, isNot(contains('legacyAssistantRecommendationProvider')));
      expect(
        source,
        isNot(contains('legacyAssistantDashboardBriefingProvider')),
      );
      expect(source, isNot(contains('assistantDashboardBriefingProvider')));
      expect(source, isNot(contains('FinancialRecommendationService')));
      expect(source, isNot(contains('FinancialDecisionOptionsService')));
      expect(source, isNot(contains('FinancialExplanationService')));
    });

    test('resolves without provider cycle', () async {
      final option = _option(
        FinancialIntelligenceDecisionOptionType.improveCategoryCoverage,
      );
      final selection = _selection(option);
      final container = _container(
        selection: selection,
        explanation: _explanation(selection),
        legacyType: FinancialDecisionOptionType.improveCategorization,
        shadowType:
            FinancialIntelligenceRecommendationType.improveCategoryCoverage,
      );
      addTearDown(container.dispose);

      final result = await container.read(
        financialIntelligenceRuntimeRecommendationCandidateProvider.future,
      );

      expect(result, isA<Success>());
    });

    test('Dashboard and UI do not import runtime adapter provider', () {
      for (final file in _uiFiles()) {
        final source = file.readAsStringSync();

        expect(
          source,
          isNot(
            contains(
              'financialIntelligenceRuntimeRecommendationCandidateProvider',
            ),
          ),
          reason: file.path,
        );
        expect(
          source,
          isNot(
            contains('FinancialIntelligenceRuntimeRecommendationCandidate'),
          ),
          reason: file.path,
        );
      }
    });
  });
}

ProviderContainer _container({
  required FinancialIntelligenceRecommendationSelectionSnapshot selection,
  required FinancialIntelligenceRecommendationExplanationSnapshot explanation,
  FinancialDecisionOptionType legacyType =
      FinancialDecisionOptionType.reduceDiscretionarySpending,
  FinancialIntelligenceRecommendationType shadowType =
      FinancialIntelligenceRecommendationType.reduceReducibleSpending,
}) {
  return ProviderContainer(
    overrides: [
      financialIntelligenceRecommendationSelectionProvider.overrideWith(
        (ref) async => Success(selection),
      ),
      financialIntelligenceRecommendationExplanationProvider.overrideWith(
        (ref) async => Success(explanation),
      ),
      financialRecommendationComparisonProvider.overrideWith(
        (ref) async => Success(
          buildTestRecommendationComparison(
            legacyType: legacyType,
            shadowTypes: [shadowType],
            conflictLevel: FinancialRecommendationConflictLevel.aligned,
          ),
        ),
      ),
    ],
  );
}

FinancialIntelligenceRecommendationSelectionSnapshot _selection(
  FinancialIntelligenceDecisionOption selected,
) {
  return FinancialIntelligenceRecommendationSelectionSnapshot(
    selection: FinancialIntelligenceRecommendationSelection(
      selectedOption: selected,
      rejectedOptions: const [],
      selectionReason:
          FinancialIntelligenceRecommendationSelectionReason.priorityOrder,
      isDiagnosticsOnly: true,
    ),
  );
}

FinancialIntelligenceRecommendationExplanationSnapshot _explanation(
  FinancialIntelligenceRecommendationSelectionSnapshot selection,
) {
  final selected = selection.selectedOption!;

  return FinancialIntelligenceRecommendationExplanationSnapshot(
    explanation: FinancialIntelligenceRecommendationExplanation(
      selectedRecommendation: selected,
      selectionReason: selection.selectionReason,
      supportingProblems: const [],
      supportingParityMetrics: const [],
      evidence: [
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
  FinancialIntelligenceDecisionOptionType type,
) {
  return FinancialIntelligenceDecisionOption(
    optionId: 'option.${type.name}',
    type: type,
    period: FinancialModelPeriod(
      start: DateTime.utc(2035, 6),
      end: DateTime.utc(2035, 7),
    ),
    sourceProblemIds: ['problem.${type.name}'],
    sourceProblemTypes: [
      type == FinancialIntelligenceDecisionOptionType.improveCategoryCoverage
          ? FinancialIntelligenceProblemType.classificationCoverageGap
          : FinancialIntelligenceProblemType.reducibleSpendingPressure,
    ],
    parityMetric: null,
    parityStatus: null,
    legacyModelValue: null,
    intelligenceModelValue: null,
    isPositiveSignal: false,
    isWarning: true,
    isDiagnosticsOnly: true,
  );
}

List<File> _uiFiles() {
  final files = <File>[];
  final dashboard = Directory('lib/features/dashboard');
  if (dashboard.existsSync()) {
    files.addAll(dashboard.listSync(recursive: true).whereType<File>());
  }
  final features = Directory('lib/features');
  if (features.existsSync()) {
    files.addAll(
      features
          .listSync(recursive: true)
          .whereType<File>()
          .where(
            (file) => file.path
                .split(Platform.pathSeparator)
                .contains('presentation'),
          ),
    );
  }
  return files.toSet().toList(growable: false);
}
