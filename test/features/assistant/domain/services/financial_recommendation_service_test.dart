import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:ophir/features/assistant/domain/entities/financial_decision_expected_model_change.dart';
import 'package:ophir/features/assistant/domain/entities/financial_decision_objective.dart';
import 'package:ophir/features/assistant/domain/entities/financial_decision_objective_type.dart';
import 'package:ophir/features/assistant/domain/entities/financial_decision_option.dart';
import 'package:ophir/features/assistant/domain/entities/financial_decision_option_applicability.dart';
import 'package:ophir/features/assistant/domain/entities/financial_decision_option_availability_reason.dart';
import 'package:ophir/features/assistant/domain/entities/financial_decision_option_condition.dart';
import 'package:ophir/features/assistant/domain/entities/financial_decision_option_cost.dart';
import 'package:ophir/features/assistant/domain/entities/financial_decision_option_cost_level.dart';
import 'package:ophir/features/assistant/domain/entities/financial_decision_option_effect_horizon.dart';
import 'package:ophir/features/assistant/domain/entities/financial_decision_option_evidence.dart';
import 'package:ophir/features/assistant/domain/entities/financial_decision_option_impact.dart';
import 'package:ophir/features/assistant/domain/entities/financial_decision_option_limitation.dart';
import 'package:ophir/features/assistant/domain/entities/financial_decision_option_metadata.dart';
import 'package:ophir/features/assistant/domain/entities/financial_decision_option_risk.dart';
import 'package:ophir/features/assistant/domain/entities/financial_decision_option_risk_level.dart';
import 'package:ophir/features/assistant/domain/entities/financial_decision_option_status.dart';
import 'package:ophir/features/assistant/domain/entities/financial_decision_option_type.dart';
import 'package:ophir/features/assistant/domain/entities/financial_decision_target.dart';
import 'package:ophir/features/assistant/domain/entities/financial_decision_target_direction.dart';
import 'package:ophir/features/assistant/domain/entities/financial_model_type.dart';
import 'package:ophir/features/assistant/domain/entities/financial_model_unit.dart';
import 'package:ophir/features/assistant/domain/entities/financial_problem_confidence.dart';
import 'package:ophir/features/assistant/domain/entities/financial_problem_type.dart';
import 'package:ophir/features/assistant/domain/entities/financial_rejected_alternative_reason.dart';
import 'package:ophir/features/assistant/domain/services/financial_recommendation_service.dart';

final _generatedAt = DateTime(2026, 3);
final _service = FinancialRecommendationService(generatedAt: _generatedAt);

void main() {
  group('FinancialRecommendationService', () {
    test('empty input returns null', () {
      expect(_service.recommend(const []), isNull);
    });

    test('never selects futureUnavailable', () {
      final recommendation = _service.recommend([
        _option(
          FinancialDecisionOptionType.useExistingReserves,
          applicability: FinancialDecisionOptionApplicability.futureUnavailable,
        ),
        _option(FinancialDecisionOptionType.reviewExpenseStructure),
      ]);

      expect(
        recommendation!.selectedOptionType,
        FinancialDecisionOptionType.reviewExpenseStructure,
      );
      expect(
        recommendation.rejectedAlternatives.single.reasonCodes,
        contains(FinancialRejectedAlternativeReason.futureUnavailable),
      );
    });

    test('never selects notApplicable', () {
      final recommendation = _service.recommend([
        _option(
          FinancialDecisionOptionType.reduceRecurringCommitments,
          applicability: FinancialDecisionOptionApplicability.notApplicable,
        ),
        _option(FinancialDecisionOptionType.reviewExpenseStructure),
      ]);

      expect(
        recommendation!.selectedOptionType,
        FinancialDecisionOptionType.reviewExpenseStructure,
      );
      expect(
        recommendation.rejectedAlternatives.single.reasonCodes,
        contains(FinancialRejectedAlternativeReason.notApplicable),
      );
    });

    test('prefers applicable over conditional', () {
      final recommendation = _service.recommend([
        _option(
          FinancialDecisionOptionType.reduceDiscretionarySpending,
          applicability: FinancialDecisionOptionApplicability.conditional,
          expectedModelChangeCount: 4,
        ),
        _option(
          FinancialDecisionOptionType.reviewExpenseStructure,
          expectedModelChangeCount: 1,
        ),
      ]);

      expect(
        recommendation!.selectedOptionType,
        FinancialDecisionOptionType.reviewExpenseStructure,
      );
    });

    test('selects conditional when no applicable option exists', () {
      final recommendation = _service.recommend([
        _option(
          FinancialDecisionOptionType.collectMoreData,
          applicability: FinancialDecisionOptionApplicability.conditional,
        ),
      ]);

      expect(
        recommendation!.selectedOptionType,
        FinancialDecisionOptionType.collectMoreData,
      );
    });

    test('returns null when all options are unavailable', () {
      final recommendation = _service.recommend([
        _option(
          FinancialDecisionOptionType.useExistingReserves,
          applicability: FinancialDecisionOptionApplicability.futureUnavailable,
        ),
        _option(
          FinancialDecisionOptionType.reduceRecurringCommitments,
          applicability: FinancialDecisionOptionApplicability.notApplicable,
        ),
      ]);

      expect(recommendation, isNull);
    });

    test('selects higher impact when cost and risk are comparable', () {
      final recommendation = _service.recommend([
        _option(
          FinancialDecisionOptionType.reviewLargeExpense,
          expectedModelChangeCount: 1,
        ),
        _option(
          FinancialDecisionOptionType.reduceDiscretionarySpending,
          expectedModelChangeCount: 3,
        ),
      ]);

      expect(
        recommendation!.selectedOptionType,
        FinancialDecisionOptionType.reduceDiscretionarySpending,
      );
    });

    test('selects lower risk when impact is comparable', () {
      final recommendation = _service.recommend([
        _option(
          FinancialDecisionOptionType.optimizeEssentialExpenses,
          riskLevel: FinancialDecisionOptionRiskLevel.high,
        ),
        _option(
          FinancialDecisionOptionType.reviewExpenseStructure,
          riskLevel: FinancialDecisionOptionRiskLevel.none,
        ),
      ]);

      expect(
        recommendation!.selectedOptionType,
        FinancialDecisionOptionType.reviewExpenseStructure,
      );
    });

    test('selects lower cost when impact and risk are comparable', () {
      final recommendation = _service.recommend([
        _option(
          FinancialDecisionOptionType.reduceDiscretionarySpending,
          costLevel: FinancialDecisionOptionCostLevel.high,
        ),
        _option(
          FinancialDecisionOptionType.reviewExpenseStructure,
          costLevel: FinancialDecisionOptionCostLevel.low,
        ),
      ]);

      expect(
        recommendation!.selectedOptionType,
        FinancialDecisionOptionType.reviewExpenseStructure,
      );
    });

    test('penalizes mayWorsenProblemTypes', () {
      final recommendation = _service.recommend([
        _option(
          FinancialDecisionOptionType.useExistingReserves,
          mayWorsenProblemTypes: const [
            FinancialProblemType.weakSavingsCapacity,
          ],
        ),
        _option(FinancialDecisionOptionType.reviewExpenseStructure),
      ]);

      expect(
        recommendation!.selectedOptionType,
        FinancialDecisionOptionType.reviewExpenseStructure,
      );
    });

    test('handles confidence deterministically', () {
      final recommendation = _service.recommend([
        _option(
          FinancialDecisionOptionType.reviewLargeExpense,
          confidence: FinancialProblemConfidence.low,
        ),
        _option(
          FinancialDecisionOptionType.reviewExpenseStructure,
          confidence: FinancialProblemConfidence.high,
        ),
      ]);

      expect(
        recommendation!.selectedOptionType,
        FinancialDecisionOptionType.reviewExpenseStructure,
      );
    });

    test('handles horizon deterministically', () {
      final recommendation = _service.recommend([
        _option(
          FinancialDecisionOptionType.reviewLargeExpense,
          horizon: FinancialDecisionOptionEffectHorizon.longTerm,
        ),
        _option(
          FinancialDecisionOptionType.reviewExpenseStructure,
          horizon: FinancialDecisionOptionEffectHorizon.immediate,
        ),
      ]);

      expect(
        recommendation!.selectedOptionType,
        FinancialDecisionOptionType.reviewExpenseStructure,
      );
    });

    test('stable ordering does not depend on input order', () {
      final firstOption = _option(
        FinancialDecisionOptionType.reviewExpenseStructure,
      );
      final secondOption = _option(
        FinancialDecisionOptionType.reviewLargeExpense,
      );

      final first = _service.recommend([firstOption, secondOption]);
      final second = _service.recommend([secondOption, firstOption]);

      expect(second!.selectedOptionId, first!.selectedOptionId);
      expect(second.selectedOptionType, first.selectedOptionType);
    });

    test('includes selected option id and type', () {
      final recommendation = _service.recommend([
        _option(FinancialDecisionOptionType.reviewExpenseStructure),
      ]);

      expect(recommendation!.selectedOptionId, 'option.reviewExpenseStructure');
      expect(
        recommendation.selectedOptionType,
        FinancialDecisionOptionType.reviewExpenseStructure,
      );
    });

    test('includes rejected alternatives', () {
      final recommendation = _service.recommend([
        _option(FinancialDecisionOptionType.reviewExpenseStructure),
        _option(FinancialDecisionOptionType.reviewLargeExpense),
      ]);

      expect(recommendation!.rejectedAlternatives, hasLength(1));
      expect(
        recommendation.rejectedAlternatives.single.optionType,
        FinancialDecisionOptionType.reviewLargeExpense,
      );
    });

    test('rejected alternatives contain reason codes, not text', () {
      final recommendation = _service.recommend([
        _option(FinancialDecisionOptionType.reviewExpenseStructure),
        _option(FinancialDecisionOptionType.reviewLargeExpense),
      ]);

      final rejected = recommendation!.rejectedAlternatives.single;

      expect(rejected.reasonCodes, isNotEmpty);
      expect(
        rejected.reasonCodes,
        everyElement(isA<FinancialRejectedAlternativeReason>()),
      );
    });

    test('rejected alternative preserves its own option evidence', () {
      final recommendation = _service.recommend([
        _option(
          FinancialDecisionOptionType.reviewExpenseStructure,
          sourceProblemIds: const ['problem.selected'],
          sourceDeviationIds: const ['deviation.selected'],
          sourceModelIds: const ['model.selected'],
        ),
        _option(
          FinancialDecisionOptionType.reviewLargeExpense,
          sourceProblemIds: const ['problem.rejected'],
          sourceDeviationIds: const ['deviation.rejected'],
          sourceModelIds: const ['model.rejected'],
        ),
      ]);

      final rejected = recommendation!.rejectedAlternatives.single;

      expect(rejected.evidence.sourceOptionId, 'option.reviewLargeExpense');
      expect(rejected.evidence.sourceProblemIds, ['problem.rejected']);
      expect(rejected.evidence.sourceProblemTypes, ['expensePressure']);
      expect(rejected.evidence.sourceDeviationIds, ['deviation.rejected']);
      expect(rejected.evidence.sourceModelIds, ['model.rejected']);
    });

    test('preserves evidence only from option evidence', () {
      final recommendation = _service.recommend([
        _option(
          FinancialDecisionOptionType.reviewExpenseStructure,
          sourceProblemIds: const ['problem.expense'],
          sourceDeviationIds: const ['deviation.expense'],
          sourceModelIds: const ['model.expense'],
        ),
      ]);

      expect(
        recommendation!.evidence.sourceOptionId,
        'option.reviewExpenseStructure',
      );
      expect(recommendation.evidence.sourceProblemIds, ['problem.expense']);
      expect(recommendation.evidence.sourceProblemTypes, ['expensePressure']);
      expect(recommendation.evidence.sourceDeviationIds, ['deviation.expense']);
      expect(recommendation.evidence.sourceModelIds, ['model.expense']);
    });

    test('phase 6 files do not import lower layers or UI concepts', () {
      final files = _phase6Files();
      final forbiddenImportTokens = [
        'financial_facts',
        'financial_fact',
        'financial_model_result',
        'financial_deviation',
        'financial_problem',
        'operation',
        'category',
        'account',
        'dashboard',
        'ui',
      ];

      for (final file in files) {
        final importLines = file.readAsLinesSync().where(
          (line) => line.trimLeft().startsWith('import '),
        );

        for (final line in importLines) {
          final normalized = line.toLowerCase();
          for (final token in forbiddenImportTokens) {
            expect(normalized, isNot(contains(token)), reason: file.path);
          }
        }
      }
    });

    test('phase 6 files do not contain user-facing explanation vocabulary', () {
      final bannedTokens = {
        'ai',
        'markdown',
        'random',
        'prompt',
        'measurement',
        'learning',
        'forecast',
        'budget',
        'goal',
        'explanation',
        'dashboard',
        'l10n',
        'copy',
        'rationale',
        'text',
      };

      for (final file in _phase6Files()) {
        final source = file.readAsStringSync();
        final normalized = source.toLowerCase();
        expect(source, isNot(contains('DateTime.now')), reason: file.path);
        expect(normalized, isNot(contains('user-facing')), reason: file.path);
        expect(normalized, isNot(contains('user facing')), reason: file.path);
        expect(
          normalized,
          isNot(contains('recommendation text')),
          reason: file.path,
        );
        final strippedSource = normalized.replaceAll(
          'financial-recommendations-v1',
          '',
        );
        final tokens = strippedSource.split(RegExp('[^a-z0-9-]+')).toSet();

        for (final token in bannedTokens) {
          expect(tokens, isNot(contains(token)), reason: file.path);
        }
      }
    });
  });
}

List<File> _phase6Files() {
  return Directory('lib/features/assistant')
      .listSync(recursive: true)
      .whereType<File>()
      .where((file) {
        final name = file.uri.pathSegments.last;
        return name.startsWith('financial_recommendation') ||
            name.startsWith('financial_rejected_alternative');
      })
      .toList(growable: false);
}

FinancialDecisionOption _option(
  FinancialDecisionOptionType type, {
  FinancialDecisionOptionApplicability applicability =
      FinancialDecisionOptionApplicability.applicable,
  FinancialDecisionOptionCostLevel costLevel =
      FinancialDecisionOptionCostLevel.low,
  FinancialDecisionOptionRiskLevel riskLevel =
      FinancialDecisionOptionRiskLevel.low,
  FinancialProblemConfidence confidence = FinancialProblemConfidence.medium,
  FinancialDecisionOptionEffectHorizon horizon =
      FinancialDecisionOptionEffectHorizon.immediate,
  int expectedModelChangeCount = 2,
  List<FinancialProblemType> mayWorsenProblemTypes = const [],
  List<String> sourceProblemIds = const ['problem.expense'],
  List<String> sourceDeviationIds = const ['deviation.expense'],
  List<String> sourceModelIds = const ['model.expense'],
}) {
  return FinancialDecisionOption(
    optionId: 'option.${type.name}',
    optionType: type,
    status: _statusFor(applicability),
    applicability: applicability,
    linkedProblemIds: sourceProblemIds,
    solvesProblemTypes: const [FinancialProblemType.expensePressure],
    mayWorsenProblemTypes: mayWorsenProblemTypes,
    objectives: const [
      FinancialDecisionObjective(
        objectiveId: 'objective.expense',
        objectiveType: FinancialDecisionObjectiveType.reduceExpensePressure,
        sourceProblemId: 'problem.expense',
        sourceProblemType: FinancialProblemType.expensePressure,
      ),
    ],
    targets: [
      FinancialDecisionTarget(
        targetModelType: FinancialModelType.expenseToIncomeRatio,
        desiredDirection: FinancialDecisionTargetDirection.decrease,
        expectedImprovement: null,
        unit: FinancialModelUnit.percentage,
        confidence: confidence,
      ),
    ],
    expectedModelChanges: [
      for (var index = 0; index < expectedModelChangeCount; index++)
        FinancialDecisionExpectedModelChange(
          modelType: FinancialModelType.expenseToIncomeRatio,
          direction: FinancialDecisionTargetDirection.decrease,
          expectedChange: null,
          unit: FinancialModelUnit.percentage,
          confidence: confidence,
        ),
    ],
    impact: FinancialDecisionOptionImpact(
      isQuantitative: false,
      effectHorizon: horizon,
    ),
    cost: FinancialDecisionOptionCost(
      effort: costLevel,
      timeCost: costLevel,
      financialCost: FinancialDecisionOptionCostLevel.none,
    ),
    risk: FinancialDecisionOptionRisk(
      level: riskLevel,
      mayWorsenProblemTypes: mayWorsenProblemTypes,
    ),
    conditions: const <FinancialDecisionOptionCondition>[],
    limitations: const <FinancialDecisionOptionLimitation>[],
    availabilityReasons: const <FinancialDecisionOptionAvailabilityReason>[],
    evidence: FinancialDecisionOptionEvidence(
      sourceProblemIds: sourceProblemIds,
      sourceProblemTypes: const [FinancialProblemType.expensePressure],
      sourceDeviationIds: sourceDeviationIds,
      sourceModelIds: sourceModelIds,
    ),
    metadata: FinancialDecisionOptionMetadata(
      generatedAt: _generatedAt,
      engineVersion: 'test-options',
      ruleId: 'rule.${type.name}',
    ),
    effectHorizon: horizon,
  );
}

FinancialDecisionOptionStatus _statusFor(
  FinancialDecisionOptionApplicability applicability,
) {
  return switch (applicability) {
    FinancialDecisionOptionApplicability.applicable =>
      FinancialDecisionOptionStatus.available,
    FinancialDecisionOptionApplicability.conditional =>
      FinancialDecisionOptionStatus.conditional,
    FinancialDecisionOptionApplicability.notApplicable =>
      FinancialDecisionOptionStatus.unavailable,
    FinancialDecisionOptionApplicability.futureUnavailable =>
      FinancialDecisionOptionStatus.futureUnavailable,
  };
}
