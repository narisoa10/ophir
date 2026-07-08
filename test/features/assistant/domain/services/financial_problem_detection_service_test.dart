import 'package:flutter_test/flutter_test.dart';
import 'package:ophir/features/assistant/domain/entities/financial_deviation.dart';
import 'package:ophir/features/assistant/domain/entities/financial_deviation_confidence.dart';
import 'package:ophir/features/assistant/domain/entities/financial_deviation_evidence.dart';
import 'package:ophir/features/assistant/domain/entities/financial_deviation_expected_value.dart';
import 'package:ophir/features/assistant/domain/entities/financial_deviation_limitation.dart';
import 'package:ophir/features/assistant/domain/entities/financial_deviation_metadata.dart';
import 'package:ophir/features/assistant/domain/entities/financial_deviation_severity.dart';
import 'package:ophir/features/assistant/domain/entities/financial_deviation_status.dart';
import 'package:ophir/features/assistant/domain/entities/financial_deviation_type.dart';
import 'package:ophir/features/assistant/domain/entities/financial_model_period.dart';
import 'package:ophir/features/assistant/domain/entities/financial_model_unit.dart';
import 'package:ophir/features/assistant/domain/entities/financial_problem_confidence.dart';
import 'package:ophir/features/assistant/domain/entities/financial_problem_limitation.dart';
import 'package:ophir/features/assistant/domain/entities/financial_problem_severity.dart';
import 'package:ophir/features/assistant/domain/entities/financial_problem_type.dart';
import 'package:ophir/features/assistant/domain/services/financial_problem_detection_service.dart';

const _service = FinancialProblemDetectionService();
final _period = FinancialModelPeriod(
  start: DateTime(2026, 1),
  end: DateTime(2026, 2),
);
final _nextPeriod = FinancialModelPeriod(
  start: DateTime(2026, 2),
  end: DateTime(2026, 3),
);
final _calculatedAt = DateTime(2026, 2);

void main() {
  group('FinancialProblemDetectionService', () {
    test('creates cashFlowDeficit from negativeNetCashFlow', () {
      final problems = _service.detect([
        _deviation(FinancialDeviationType.negativeNetCashFlow),
      ]);

      expect(problems, hasLength(1));
      expect(problems.single.problemType, FinancialProblemType.cashFlowDeficit);
      expect(problems.single.evidence.sourceDeviationTypes, [
        FinancialDeviationType.negativeNetCashFlow,
      ]);
    });

    test(
      'creates expensePressure from highExpenseToIncomeRatio with support',
      () {
        final problems = _service.detect([
          _deviation(FinancialDeviationType.highExpenseToIncomeRatio),
          _deviation(FinancialDeviationType.lowSavingsRate),
        ]);

        expect(
          problems.map((problem) => problem.problemType),
          contains(FinancialProblemType.expensePressure),
        );
      },
    );

    test(
      'does not create expensePressure from isolated low-signal deviation',
      () {
        final problems = _service.detect([
          _deviation(
            FinancialDeviationType.highExpenseToIncomeRatio,
            severity: FinancialDeviationSeverity.low,
          ),
        ]);

        expect(problems, isEmpty);
      },
    );

    test('creates weakSavingsCapacity from lowSavingsRate', () {
      final problems = _service.detect([
        _deviation(FinancialDeviationType.lowSavingsRate),
      ]);

      expect(
        problems.single.problemType,
        FinancialProblemType.weakSavingsCapacity,
      );
    });

    test(
      'creates discretionarySpendingPressure only with outcome pressure',
      () {
        final problems = _service.detect([
          _deviation(FinancialDeviationType.highLifestyleExpenseRatio),
          _deviation(FinancialDeviationType.lowSavingsRate),
        ]);

        expect(
          problems.map((problem) => problem.problemType),
          contains(FinancialProblemType.discretionarySpendingPressure),
        );
      },
    );

    test(
      'does not create discretionary problem from lifestyle/flexible alone',
      () {
        final problems = _service.detect([
          _deviation(FinancialDeviationType.highLifestyleExpenseRatio),
          _deviation(FinancialDeviationType.highFlexibleExpenseRatio),
        ]);

        expect(problems, isEmpty);
      },
    );

    test('creates essentialCostPressure only with outcome support', () {
      final withoutSupport = _service.detect([
        _deviation(FinancialDeviationType.highEssentialExpenseRatio),
      ]);
      final withSupport = _service.detect([
        _deviation(FinancialDeviationType.highEssentialExpenseRatio),
        _deviation(FinancialDeviationType.lowSavingsRate),
      ]);

      expect(withoutSupport, isEmpty);
      expect(
        withSupport.map((problem) => problem.problemType),
        contains(FinancialProblemType.essentialCostPressure),
      );
    });

    test(
      'creates fixedCommitmentPressure from highRecurringCommitmentLoad',
      () {
        final problems = _service.detect([
          _deviation(FinancialDeviationType.highRecurringCommitmentLoad),
        ]);

        expect(
          problems.single.problemType,
          FinancialProblemType.fixedCommitmentPressure,
        );
      },
    );

    test('creates poorDataReliability from weakDataQuality', () {
      final problems = _service.detect([
        _deviation(FinancialDeviationType.weakDataQuality),
      ]);

      expect(
        problems.single.problemType,
        FinancialProblemType.poorDataReliability,
      );
    });

    test('ignores non-calculated deviations', () {
      final problems = _service.detect([
        _deviation(
          FinancialDeviationType.negativeNetCashFlow,
          status: FinancialDeviationStatus.unavailable,
        ),
      ]);

      expect(problems, isEmpty);
    });

    test('preserves deviation evidence without raw fact references', () {
      final problems = _service.detect([
        _deviation(
          FinancialDeviationType.negativeNetCashFlow,
          sourceModelIds: const ['financial.model.netCashFlow'],
          sourceFactIds: const [
            'operation:raw',
            'category:raw',
            'account:raw',
            'fact:netCashFlow',
          ],
        ),
      ]);

      final evidence = problems.single.evidence;
      expect(evidence.sourceDeviationIds, [
        'financial.deviation.negativeNetCashFlow',
      ]);
      expect(evidence.sourceModelIds, ['financial.model.netCashFlow']);
      expect(
        evidence.sourceModelIds.any(
          (id) =>
              id.startsWith('operation:') ||
              id.startsWith('category:') ||
              id.startsWith('account:') ||
              id.startsWith('fact:'),
        ),
        isFalse,
      );
    });

    test('confidence is not simple copy from source deviation confidence', () {
      final problems = _service.detect([
        _deviation(
          FinancialDeviationType.negativeNetCashFlow,
          confidence: FinancialDeviationConfidence.high,
        ),
      ]);

      expect(problems.single.confidence, FinancialProblemConfidence.medium);
    });

    test('weak data quality reduces confidence of other problems', () {
      final withoutWeakData = _service.detect([
        _deviation(
          FinancialDeviationType.highExpenseToIncomeRatio,
          severity: FinancialDeviationSeverity.medium,
          confidence: FinancialDeviationConfidence.medium,
        ),
        _deviation(
          FinancialDeviationType.lowSavingsRate,
          confidence: FinancialDeviationConfidence.high,
        ),
      ]);
      final withWeakData = _service.detect([
        _deviation(
          FinancialDeviationType.highExpenseToIncomeRatio,
          severity: FinancialDeviationSeverity.medium,
          confidence: FinancialDeviationConfidence.medium,
        ),
        _deviation(
          FinancialDeviationType.lowSavingsRate,
          confidence: FinancialDeviationConfidence.high,
        ),
        _deviation(FinancialDeviationType.weakDataQuality),
      ]);

      final cleanExpense = withoutWeakData.singleWhere(
        (problem) =>
            problem.problemType == FinancialProblemType.expensePressure,
      );
      final limitedExpense = withWeakData.singleWhere(
        (problem) =>
            problem.problemType == FinancialProblemType.expensePressure,
      );

      expect(cleanExpense.confidence, FinancialProblemConfidence.high);
      expect(limitedExpense.confidence, FinancialProblemConfidence.medium);
      expect(
        limitedExpense.limitations,
        contains(FinancialProblemLimitation.weakDataQuality),
      );
    });

    test('related deviations merge according to policy', () {
      final problems = _service.detect([
        _deviation(FinancialDeviationType.negativeNetCashFlow),
        _deviation(FinancialDeviationType.lowSavingsRate),
      ]);

      expect(
        problems.map((problem) => problem.problemType),
        contains(FinancialProblemType.cashFlowDeficit),
      );
      expect(
        problems.map((problem) => problem.problemType),
        isNot(contains(FinancialProblemType.weakSavingsCapacity)),
      );
    });

    test('does not create duplicate problem ids', () {
      final problems = _service.detect([
        _deviation(FinancialDeviationType.highExpenseToIncomeRatio),
        _deviation(FinancialDeviationType.highExpenseToIncomeRatio),
        _deviation(FinancialDeviationType.lowSavingsRate),
      ]);
      final ids = problems.map((problem) => problem.problemId).toSet();

      expect(ids, hasLength(problems.length));
    });

    test('severity changes with supporting deviation count', () {
      final isolated = _service.detect([
        _deviation(
          FinancialDeviationType.highExpenseToIncomeRatio,
          severity: FinancialDeviationSeverity.medium,
        ),
      ]);
      final supported = _service.detect([
        _deviation(
          FinancialDeviationType.highExpenseToIncomeRatio,
          severity: FinancialDeviationSeverity.medium,
        ),
        _deviation(
          FinancialDeviationType.lowSavingsRate,
          severity: FinancialDeviationSeverity.low,
        ),
      ]);

      expect(isolated.single.severity, FinancialProblemSeverity.medium);
      expect(
        supported
            .singleWhere(
              (problem) =>
                  problem.problemType == FinancialProblemType.expensePressure,
            )
            .severity,
        FinancialProblemSeverity.high,
      );
    });

    test('limitations propagate and reduce confidence', () {
      final problems = _service.detect([
        _deviation(
          FinancialDeviationType.highRecurringCommitmentLoad,
          confidence: FinancialDeviationConfidence.low,
          limitations: const [
            FinancialDeviationLimitation.sourceUnknownRecurringPattern,
          ],
        ),
      ]);

      final problem = problems.single;
      expect(problem.confidence, FinancialProblemConfidence.low);
      expect(
        problem.limitations,
        contains(FinancialProblemLimitation.sourceUnknownRecurringPattern),
      );
      expect(
        problem.limitations,
        contains(FinancialProblemLimitation.lowSourceConfidence),
      );
    });

    test(
      'does not combine deviations from different periods into one problem',
      () {
        final problems = _service.detect([
          _deviation(
            FinancialDeviationType.highExpenseToIncomeRatio,
            severity: FinancialDeviationSeverity.low,
            period: _period,
          ),
          _deviation(
            FinancialDeviationType.lowSavingsRate,
            period: _nextPeriod,
          ),
        ]);

        expect(
          problems.map((problem) => problem.problemType),
          isNot(contains(FinancialProblemType.expensePressure)),
        );
        expect(
          problems.map((problem) => problem.problemType),
          contains(FinancialProblemType.weakSavingsCapacity),
        );
      },
    );

    test('creates independent same-type problems in different periods', () {
      final problems = _service.detect([
        _deviation(FinancialDeviationType.negativeNetCashFlow, period: _period),
        _deviation(
          FinancialDeviationType.negativeNetCashFlow,
          period: _nextPeriod,
        ),
      ]);
      final cashFlowProblems = problems
          .where(
            (problem) =>
                problem.problemType == FinancialProblemType.cashFlowDeficit,
          )
          .toList();

      expect(cashFlowProblems, hasLength(2));
      expect(
        cashFlowProblems.map((problem) => problem.problemId).toSet(),
        hasLength(2),
      );
    });

    test(
      'cashFlowDeficit in one period does not hide weakSavingsCapacity in another',
      () {
        final problems = _service.detect([
          _deviation(
            FinancialDeviationType.negativeNetCashFlow,
            period: _period,
          ),
          _deviation(
            FinancialDeviationType.lowSavingsRate,
            period: _nextPeriod,
          ),
        ]);

        expect(
          problems.map((problem) => problem.problemType),
          contains(FinancialProblemType.cashFlowDeficit),
        );
        expect(
          problems.map((problem) => problem.problemType),
          contains(FinancialProblemType.weakSavingsCapacity),
        );
      },
    );

    test(
      'supporting deviation from another period does not increase severity or confidence',
      () {
        final problems = _service.detect([
          _deviation(
            FinancialDeviationType.highExpenseToIncomeRatio,
            severity: FinancialDeviationSeverity.medium,
            period: _period,
          ),
          _deviation(
            FinancialDeviationType.lowSavingsRate,
            period: _nextPeriod,
          ),
        ]);
        final expenseProblem = problems.singleWhere(
          (problem) =>
              problem.problemType == FinancialProblemType.expensePressure,
        );

        expect(expenseProblem.severity, FinancialProblemSeverity.medium);
        expect(expenseProblem.confidence, FinancialProblemConfidence.medium);
        expect(expenseProblem.period, _period);
      },
    );

    test('merge policy deduplicates only inside one period', () {
      final problems = _service.detect([
        _deviation(
          FinancialDeviationType.highRecurringCommitmentLoad,
          period: _period,
        ),
        _deviation(
          FinancialDeviationType.highRecurringCommitmentLoad,
          period: _period,
        ),
        _deviation(
          FinancialDeviationType.highRecurringCommitmentLoad,
          period: _nextPeriod,
        ),
      ]);
      final fixedCommitmentProblems = problems
          .where(
            (problem) =>
                problem.problemType ==
                FinancialProblemType.fixedCommitmentPressure,
          )
          .toList();

      expect(fixedCommitmentProblems, hasLength(2));
      expect(
        fixedCommitmentProblems.map((problem) => problem.period).toSet(),
        hasLength(2),
      );
    });

    test('does not mix evidence between periods', () {
      final problems = _service.detect([
        _deviation(
          FinancialDeviationType.negativeNetCashFlow,
          period: _period,
          sourceModelIds: const ['financial.model.netCashFlow.current'],
        ),
        _deviation(
          FinancialDeviationType.negativeNetCashFlow,
          period: _nextPeriod,
          sourceModelIds: const ['financial.model.netCashFlow.next'],
        ),
      ]);
      final current = problems.singleWhere(
        (problem) =>
            problem.problemType == FinancialProblemType.cashFlowDeficit &&
            problem.period == _period,
      );
      final next = problems.singleWhere(
        (problem) =>
            problem.problemType == FinancialProblemType.cashFlowDeficit &&
            problem.period == _nextPeriod,
      );

      expect(current.evidence.sourceModelIds, [
        'financial.model.netCashFlow.current',
      ]);
      expect(next.evidence.sourceModelIds, [
        'financial.model.netCashFlow.next',
      ]);
    });
  });
}

FinancialDeviation _deviation(
  FinancialDeviationType type, {
  FinancialDeviationStatus status = FinancialDeviationStatus.calculated,
  FinancialDeviationSeverity severity = FinancialDeviationSeverity.high,
  FinancialDeviationConfidence confidence = FinancialDeviationConfidence.high,
  List<FinancialDeviationLimitation> limitations = const [],
  List<String> sourceModelIds = const [],
  List<String> sourceFactIds = const [],
  FinancialModelPeriod? period,
}) {
  final effectivePeriod = period ?? _period;
  return FinancialDeviation(
    deviationId: 'financial.deviation.${type.name}',
    deviationType: type,
    status: status,
    severity: severity,
    actualValue: 1,
    expectedValue: FinancialDeviationExpectedValue(
      thresholdValue: 0,
      unit: _unit(type),
      isUpperBound: true,
    ),
    deviationAmount: 1,
    unit: _unit(type),
    period: effectivePeriod,
    confidence: confidence,
    evidence: FinancialDeviationEvidence(
      sourceModelIds: sourceModelIds.isEmpty
          ? ['financial.model.${type.name}']
          : sourceModelIds,
      sourceModelEvidenceFactIds: sourceFactIds.isEmpty
          ? ['fact:${type.name}']
          : sourceFactIds,
    ),
    limitations: limitations,
    metadata: FinancialDeviationMetadata(
      calculatedAt: _calculatedAt,
      engineVersion: 'test-deviations',
      thresholdId: 'financial.deviation.threshold.${type.name}',
    ),
  );
}

FinancialModelUnit _unit(FinancialDeviationType type) {
  return switch (type) {
    FinancialDeviationType.negativeNetCashFlow => FinancialModelUnit.money,
    FinancialDeviationType.weakDataQuality => FinancialModelUnit.score,
    _ => FinancialModelUnit.ratio,
  };
}
