import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:ophir/features/assistant/domain/entities/financial_deviation_type.dart';
import 'package:ophir/features/assistant/domain/entities/financial_decision_objective_type.dart';
import 'package:ophir/features/assistant/domain/entities/financial_decision_option.dart';
import 'package:ophir/features/assistant/domain/entities/financial_decision_option_applicability.dart';
import 'package:ophir/features/assistant/domain/entities/financial_decision_option_status.dart';
import 'package:ophir/features/assistant/domain/entities/financial_decision_option_type.dart';
import 'package:ophir/features/assistant/domain/entities/financial_model_period.dart';
import 'package:ophir/features/assistant/domain/entities/financial_problem.dart';
import 'package:ophir/features/assistant/domain/entities/financial_problem_confidence.dart';
import 'package:ophir/features/assistant/domain/entities/financial_problem_evidence.dart';
import 'package:ophir/features/assistant/domain/entities/financial_problem_impact.dart';
import 'package:ophir/features/assistant/domain/entities/financial_problem_limitation.dart';
import 'package:ophir/features/assistant/domain/entities/financial_problem_metadata.dart';
import 'package:ophir/features/assistant/domain/entities/financial_problem_severity.dart';
import 'package:ophir/features/assistant/domain/entities/financial_problem_signal.dart';
import 'package:ophir/features/assistant/domain/entities/financial_problem_status.dart';
import 'package:ophir/features/assistant/domain/entities/financial_problem_type.dart';
import 'package:ophir/features/assistant/domain/services/financial_decision_option_catalog.dart';
import 'package:ophir/features/assistant/domain/services/financial_decision_options_service.dart';

const _service = FinancialDecisionOptionsService();
final _period = FinancialModelPeriod(
  start: DateTime(2026, 1),
  end: DateTime(2026, 2),
);
final _calculatedAt = DateTime(2026, 2);

void main() {
  group('FinancialDecisionOptionsService', () {
    test('generates multiple options for cashFlowDeficit', () {
      final options = _service.generate([
        _problem(FinancialProblemType.cashFlowDeficit),
      ]);

      expect(options.length, greaterThan(1));
      expect(
        options.map((option) => option.optionType),
        containsAll([
          FinancialDecisionOptionType.increaseIncome,
          FinancialDecisionOptionType.reduceDiscretionarySpending,
          FinancialDecisionOptionType.reduceRecurringCommitments,
          FinancialDecisionOptionType.useExistingReserves,
        ]),
      );
    });

    test('creates decision objective for each problem', () {
      final options = _service.generate([
        _problem(FinancialProblemType.cashFlowDeficit),
        _problem(FinancialProblemType.weakSavingsCapacity),
      ]);
      final objectives = options.expand((option) => option.objectives).toList();

      expect(
        objectives.map((objective) => objective.objectiveType).toSet(),
        containsAll([
          FinancialDecisionObjectiveType.restorePositiveCashFlow,
          FinancialDecisionObjectiveType.improveSavingsCapacity,
        ]),
      );
      expect(
        objectives.map((objective) => objective.sourceProblemId).toSet(),
        containsAll(['problem.cashFlowDeficit', 'problem.weakSavingsCapacity']),
      );
    });

    test('each option has objective, target, and expected model changes', () {
      final options = _service.generate([
        _problem(FinancialProblemType.expensePressure),
      ]);

      for (final option in options) {
        expect(option.objectives, isNotEmpty);
        expect(option.targets, isNotEmpty);
        expect(option.expectedModelChanges, isNotEmpty);
      }
    });

    test('shared option links multiple problems without duplication', () {
      final options = _service.generate([
        _problem(FinancialProblemType.cashFlowDeficit),
        _problem(FinancialProblemType.weakSavingsCapacity),
      ]);
      final reduceDiscretionary = _single(
        options,
        FinancialDecisionOptionType.reduceDiscretionarySpending,
      );

      expect(
        options
            .where(
              (option) =>
                  option.optionType ==
                  FinancialDecisionOptionType.reduceDiscretionarySpending,
            )
            .length,
        1,
      );
      expect(
        reduceDiscretionary.linkedProblemIds,
        containsAll(['problem.cashFlowDeficit', 'problem.weakSavingsCapacity']),
      );
      expect(
        reduceDiscretionary.solvesProblemTypes,
        containsAll([
          FinancialProblemType.cashFlowDeficit,
          FinancialProblemType.weakSavingsCapacity,
        ]),
      );
    });

    test('deduplication preserves all linkedProblemIds and evidence', () {
      final options = _service.generate([
        _problem(
          FinancialProblemType.cashFlowDeficit,
          sourceDeviationIds: const ['deviation.cashFlow'],
          sourceModelIds: const ['model.netCashFlow'],
        ),
        _problem(
          FinancialProblemType.expensePressure,
          sourceDeviationIds: const ['deviation.expense'],
          sourceModelIds: const ['model.expenseRatio'],
        ),
      ]);
      final reviewExpense = _single(
        options,
        FinancialDecisionOptionType.reviewExpenseStructure,
      );

      expect(
        reviewExpense.linkedProblemIds,
        containsAll(['problem.cashFlowDeficit', 'problem.expensePressure']),
      );
      expect(
        reviewExpense.evidence.sourceDeviationIds,
        containsAll(['deviation.cashFlow', 'deviation.expense']),
      );
      expect(
        reviewExpense.evidence.sourceModelIds,
        containsAll(['model.netCashFlow', 'model.expenseRatio']),
      );
    });

    test('improveCategorization generated for poorDataReliability', () {
      final options = _service.generate([
        _problem(FinancialProblemType.poorDataReliability),
      ]);

      expect(
        options.map((option) => option.optionType),
        contains(FinancialDecisionOptionType.improveCategorization),
      );
    });

    test('collectMoreData generated for low confidence and poor data', () {
      final lowConfidenceOptions = _service.generate([
        _problem(
          FinancialProblemType.cashFlowDeficit,
          confidence: FinancialProblemConfidence.low,
        ),
      ]);
      final poorDataOptions = _service.generate([
        _problem(FinancialProblemType.poorDataReliability),
      ]);

      expect(
        lowConfidenceOptions.map((option) => option.optionType),
        contains(FinancialDecisionOptionType.collectMoreData),
      );
      expect(
        poorDataOptions.map((option) => option.optionType),
        contains(FinancialDecisionOptionType.collectMoreData),
      );
    });

    test(
      'reduceRecurringCommitments applicable only with fixed commitment evidence',
      () {
        final withoutEvidence = _service.generate([
          _problem(FinancialProblemType.cashFlowDeficit),
        ]);
        final withProblemLevelCommitmentContext = _service.generate([
          _problem(
            FinancialProblemType.cashFlowDeficit,
            impact: FinancialProblemImpact.commitmentFlexibility,
          ),
        ]);
        final fixedProblem = _service.generate([
          _problem(FinancialProblemType.fixedCommitmentPressure),
        ]);

        expect(
          _single(
            withoutEvidence,
            FinancialDecisionOptionType.reduceRecurringCommitments,
          ).applicability,
          FinancialDecisionOptionApplicability.notApplicable,
        );
        expect(
          _single(
            withProblemLevelCommitmentContext,
            FinancialDecisionOptionType.reduceRecurringCommitments,
          ).applicability,
          FinancialDecisionOptionApplicability.applicable,
        );
        expect(
          _single(
            fixedProblem,
            FinancialDecisionOptionType.reduceRecurringCommitments,
          ).applicability,
          FinancialDecisionOptionApplicability.applicable,
        );
      },
    );

    test('future unavailable options are explicit', () {
      final cashFlowOptions = _service.generate([
        _problem(FinancialProblemType.cashFlowDeficit),
      ]);
      final expenseOptions = _service.generate([
        _problem(FinancialProblemType.expensePressure),
      ]);

      expect(
        _single(
          cashFlowOptions,
          FinancialDecisionOptionType.useExistingReserves,
        ).status,
        FinancialDecisionOptionStatus.futureUnavailable,
      );
      expect(
        _single(
          expenseOptions,
          FinancialDecisionOptionType.adjustBudgetUnavailable,
        ).status,
        FinancialDecisionOptionStatus.futureUnavailable,
      );
      expect(
        _single(
          cashFlowOptions,
          FinancialDecisionOptionType.reviseFinancialStrategy,
        ).status,
        FinancialDecisionOptionStatus.futureUnavailable,
      );
    });

    test('deterministic output order is stable but not priority', () {
      final problems = [
        _problem(FinancialProblemType.cashFlowDeficit),
        _problem(FinancialProblemType.expensePressure),
      ];
      final first = _service.generate(problems);
      final second = _service.generate(problems);

      expect(
        second.map((option) => option.optionType),
        first.map((option) => option.optionType),
      );
      expect(first.map((option) => option.optionType).take(3), [
        FinancialDecisionOptionType.increaseIncome,
        FinancialDecisionOptionType.reduceDiscretionarySpending,
        FinancialDecisionOptionType.reduceRecurringCommitments,
      ]);
    });

    test(
      'evidence preserves problem ids and does not reference raw inputs',
      () {
        final options = _service.generate([
          _problem(
            FinancialProblemType.cashFlowDeficit,
            sourceDeviationIds: const ['deviation.cashFlow'],
            sourceModelIds: const [
              'model.netCashFlow',
              'operation:raw',
              'category:raw',
              'account:raw',
              'fact:raw',
            ],
          ),
        ]);
        final option = _single(
          options,
          FinancialDecisionOptionType.increaseIncome,
        );

        expect(option.evidence.sourceProblemIds, ['problem.cashFlowDeficit']);
        expect(option.evidence.sourceDeviationIds, ['deviation.cashFlow']);
        expect(option.evidence.sourceModelIds, ['model.netCashFlow']);
      },
    );

    test('option can declare mayWorsenProblemTypes', () {
      final options = _service.generate([
        _problem(FinancialProblemType.cashFlowDeficit),
      ]);
      final reserves = _single(
        options,
        FinancialDecisionOptionType.useExistingReserves,
      );

      expect(
        reserves.mayWorsenProblemTypes,
        contains(FinancialProblemType.weakSavingsCapacity),
      );
      expect(
        reserves.risk.mayWorsenProblemTypes,
        contains(FinancialProblemType.weakSavingsCapacity),
      );
    });

    test('empty input does not create fake options', () {
      expect(_service.generate(const []), isEmpty);
    });

    test('each option type has exactly one catalog rule', () {
      final catalogTypes = FinancialDecisionOptionCatalog.rules
          .map((rule) => rule.optionType)
          .toList();

      expect(catalogTypes.toSet(), FinancialDecisionOptionType.values.toSet());
      expect(catalogTypes.length, FinancialDecisionOptionType.values.length);

      for (final optionType in FinancialDecisionOptionType.values) {
        expect(
          FinancialDecisionOptionCatalog.ruleFor(optionType).optionType,
          optionType,
        );
      }
    });

    test('each catalog rule defines required option fields', () {
      for (final rule in FinancialDecisionOptionCatalog.rules) {
        expect(rule.ruleId, isNotEmpty, reason: rule.optionType.name);
        expect(
          rule.solvesProblemTypes,
          isNotEmpty,
          reason: rule.optionType.name,
        );
        expect(rule.targets, isNotEmpty, reason: rule.optionType.name);
        expect(
          rule.expectedModelChanges,
          isNotEmpty,
          reason: rule.optionType.name,
        );
        expect(rule.cost, isNotNull, reason: rule.optionType.name);
        expect(rule.risk, isNotNull, reason: rule.optionType.name);
        expect(rule.effectHorizon, isNotNull, reason: rule.optionType.name);

        final generated = _service.generate([
          _problem(rule.solvesProblemTypes.first),
        ]);
        final option = _single(generated, rule.optionType);
        expect(option.impact, isNotNull, reason: rule.optionType.name);
        expect(option.cost, rule.cost, reason: rule.optionType.name);
        expect(option.risk, rule.risk, reason: rule.optionType.name);
        expect(
          option.effectHorizon,
          rule.effectHorizon,
          reason: rule.optionType.name,
        );
      }
    });

    test('all option types are generated explicitly', () {
      final options = _service.generate([
        for (final type in FinancialProblemType.values) _problem(type),
      ]);
      final generatedTypes = options.map((option) => option.optionType).toSet();

      expect(generatedTypes, containsAll(FinancialDecisionOptionType.values));
      expect(
        generatedTypes,
        contains(FinancialDecisionOptionType.increaseIncome),
      );
      expect(
        generatedTypes,
        contains(FinancialDecisionOptionType.reduceDiscretionarySpending),
      );
      expect(
        generatedTypes,
        contains(FinancialDecisionOptionType.reduceRecurringCommitments),
      );
      expect(
        generatedTypes,
        contains(FinancialDecisionOptionType.optimizeEssentialExpenses),
      );
      expect(
        generatedTypes,
        contains(FinancialDecisionOptionType.reviewExpenseStructure),
      );
      expect(
        generatedTypes,
        contains(FinancialDecisionOptionType.reviewLargeExpense),
      );
      expect(
        generatedTypes,
        contains(FinancialDecisionOptionType.improveCategorization),
      );
      expect(
        generatedTypes,
        contains(FinancialDecisionOptionType.confirmRecurringOperations),
      );
      expect(
        generatedTypes,
        contains(FinancialDecisionOptionType.collectMoreData),
      );
      expect(
        generatedTypes,
        contains(FinancialDecisionOptionType.useExistingReserves),
      );
      expect(
        generatedTypes,
        contains(FinancialDecisionOptionType.buildSavingsCapacity),
      );
      expect(
        generatedTypes,
        contains(FinancialDecisionOptionType.reviseFinancialStrategy),
      );
      expect(
        generatedTypes,
        contains(FinancialDecisionOptionType.restructureObligations),
      );
      expect(
        generatedTypes,
        contains(FinancialDecisionOptionType.adjustBudgetUnavailable),
      );
      expect(
        generatedTypes,
        contains(FinancialDecisionOptionType.deferOptionalSpending),
      );
      expect(
        generatedTypes,
        contains(FinancialDecisionOptionType.doNothingAndMonitor),
      );
    });

    test('all problem types create matching objectives', () {
      final options = _service.generate([
        for (final type in FinancialProblemType.values) _problem(type),
      ]);
      final objectives = options.expand((option) => option.objectives).toList();

      expect(
        objectives.map((objective) => objective.sourceProblemType).toSet(),
        FinancialProblemType.values.toSet(),
      );
      expect(
        objectives.map((objective) => objective.objectiveType).toSet(),
        FinancialDecisionObjectiveType.values.toSet(),
      );
    });

    test('all applicability statuses are covered', () {
      final applicable = _single(
        _service.generate([
          _problem(FinancialProblemType.fixedCommitmentPressure),
        ]),
        FinancialDecisionOptionType.reduceRecurringCommitments,
      );
      final conditional = _single(
        _service.generate([_problem(FinancialProblemType.cashFlowDeficit)]),
        FinancialDecisionOptionType.collectMoreData,
      );
      final notApplicable = _single(
        _service.generate([_problem(FinancialProblemType.cashFlowDeficit)]),
        FinancialDecisionOptionType.reduceRecurringCommitments,
      );
      final futureUnavailable = _single(
        _service.generate([_problem(FinancialProblemType.cashFlowDeficit)]),
        FinancialDecisionOptionType.useExistingReserves,
      );

      expect(
        applicable.applicability,
        FinancialDecisionOptionApplicability.applicable,
      );
      expect(
        conditional.applicability,
        FinancialDecisionOptionApplicability.conditional,
      );
      expect(
        notApplicable.applicability,
        FinancialDecisionOptionApplicability.notApplicable,
      );
      expect(
        futureUnavailable.applicability,
        FinancialDecisionOptionApplicability.futureUnavailable,
      );
    });

    test(
      'deduplication preserves linked problems, objectives, and evidence',
      () {
        final options = _service.generate([
          _problem(
            FinancialProblemType.cashFlowDeficit,
            sourceDeviationIds: const ['deviation.cashFlow'],
            sourceModelIds: const ['model.netCashFlow'],
          ),
          _problem(
            FinancialProblemType.expensePressure,
            sourceDeviationIds: const ['deviation.expense'],
            sourceModelIds: const ['model.expenseRatio'],
          ),
        ]);
        final option = _single(
          options,
          FinancialDecisionOptionType.reviewExpenseStructure,
        );

        expect(
          option.linkedProblemIds,
          containsAll(['problem.cashFlowDeficit', 'problem.expensePressure']),
        );
        expect(
          option.objectives.map((objective) => objective.sourceProblemId),
          containsAll(['problem.cashFlowDeficit', 'problem.expensePressure']),
        );
        expect(
          option.evidence.sourceProblemIds,
          containsAll(['problem.cashFlowDeficit', 'problem.expensePressure']),
        );
        expect(
          option.evidence.sourceDeviationIds,
          containsAll(['deviation.cashFlow', 'deviation.expense']),
        );
        expect(
          option.evidence.sourceModelIds,
          containsAll(['model.netCashFlow', 'model.expenseRatio']),
        );
      },
    );

    test('phase 5 files do not contain ranking or UI vocabulary', () {
      final bannedTokens = {
        'recommendation',
        'priority',
        'rank',
        'score',
        'best',
        'selected',
        'rationale',
        'rejected',
        'measurement',
        'dashboard',
        'l10n',
      };
      final files = Directory('lib/features/assistant')
          .listSync(recursive: true)
          .whereType<File>()
          .where((file) {
            final name = file.uri.pathSegments.last;
            return name.startsWith('financial_decision_') ||
                name.endsWith('_decision_options_service.dart');
          });

      for (final file in files) {
        final source = file.readAsStringSync().toLowerCase();
        final tokens = source.split(RegExp('[^a-z0-9-]+')).toSet();

        for (final token in bannedTokens) {
          expect(tokens, isNot(contains(token)), reason: file.path);
        }
        expect(source, isNot(contains('user-facing')), reason: file.path);
        expect(source, isNot(contains('user facing')), reason: file.path);
      }
    });
  });
}

FinancialDecisionOption _single(
  List<FinancialDecisionOption> options,
  FinancialDecisionOptionType type,
) {
  return options.singleWhere((option) => option.optionType == type);
}

FinancialProblem _problem(
  FinancialProblemType type, {
  FinancialProblemConfidence confidence = FinancialProblemConfidence.high,
  FinancialProblemImpact? impact,
  List<String>? sourceDeviationIds,
  List<FinancialDeviationType>? sourceDeviationTypes,
  List<String>? sourceModelIds,
}) {
  return FinancialProblem(
    problemId: 'problem.${type.name}',
    problemType: type,
    status: FinancialProblemStatus.detected,
    severity: FinancialProblemSeverity.high,
    confidence: confidence,
    impact: impact ?? _impact(type),
    period: _period,
    signals: const <FinancialProblemSignal>[],
    evidence: FinancialProblemEvidence(
      sourceDeviationIds: sourceDeviationIds ?? ['deviation.${type.name}'],
      sourceDeviationTypes: sourceDeviationTypes ?? [_deviationType(type)],
      sourceModelIds: sourceModelIds ?? ['model.${type.name}'],
    ),
    limitations: const <FinancialProblemLimitation>[],
    metadata: FinancialProblemMetadata(
      calculatedAt: _calculatedAt,
      engineVersion: 'test-problems',
      ruleId: 'rule.${type.name}',
    ),
  );
}

FinancialProblemImpact _impact(FinancialProblemType type) {
  return switch (type) {
    FinancialProblemType.cashFlowDeficit => FinancialProblemImpact.cashFlow,
    FinancialProblemType.expensePressure ||
    FinancialProblemType.discretionarySpendingPressure ||
    FinancialProblemType.essentialCostPressure =>
      FinancialProblemImpact.spendingFlexibility,
    FinancialProblemType.weakSavingsCapacity =>
      FinancialProblemImpact.savingsCapacity,
    FinancialProblemType.fixedCommitmentPressure =>
      FinancialProblemImpact.commitmentFlexibility,
    FinancialProblemType.poorDataReliability =>
      FinancialProblemImpact.dataReliability,
  };
}

FinancialDeviationType _deviationType(FinancialProblemType type) {
  return switch (type) {
    FinancialProblemType.cashFlowDeficit =>
      FinancialDeviationType.negativeNetCashFlow,
    FinancialProblemType.expensePressure =>
      FinancialDeviationType.highExpenseToIncomeRatio,
    FinancialProblemType.weakSavingsCapacity =>
      FinancialDeviationType.lowSavingsRate,
    FinancialProblemType.discretionarySpendingPressure =>
      FinancialDeviationType.highFlexibleExpenseRatio,
    FinancialProblemType.essentialCostPressure =>
      FinancialDeviationType.highEssentialExpenseRatio,
    FinancialProblemType.fixedCommitmentPressure =>
      FinancialDeviationType.highRecurringCommitmentLoad,
    FinancialProblemType.poorDataReliability =>
      FinancialDeviationType.weakDataQuality,
  };
}
