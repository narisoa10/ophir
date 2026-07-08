import 'package:flutter_test/flutter_test.dart';
import 'package:ophir/features/assistant/domain/entities/financial_deviation_severity.dart';
import 'package:ophir/features/assistant/domain/entities/financial_intelligence_deviation.dart';
import 'package:ophir/features/assistant/domain/entities/financial_intelligence_deviation_type.dart';
import 'package:ophir/features/assistant/domain/entities/financial_intelligence_deviations_snapshot.dart';
import 'package:ophir/features/assistant/domain/entities/financial_intelligence_model_type.dart';
import 'package:ophir/features/assistant/domain/entities/financial_intelligence_problem_type.dart';
import 'package:ophir/features/assistant/domain/entities/financial_model_period.dart';
import 'package:ophir/features/assistant/domain/entities/financial_model_unit.dart';
import 'package:ophir/features/assistant/domain/entities/financial_problem_impact.dart';
import 'package:ophir/features/assistant/domain/services/financial_intelligence_problem_detection_service.dart';

void main() {
  const service = FinancialIntelligenceProblemDetectionService();

  group('FinancialIntelligenceProblemDetectionService', () {
    test('maps every shadow deviation to its shadow problem type', () {
      final problems = service.detect(
        FinancialIntelligenceDeviationsSnapshot(
          deviations: [
            _deviation(
              FinancialIntelligenceDeviationType.ordinarySpendingPressure,
            ),
            _deviation(
              FinancialIntelligenceDeviationType.mandatorySpendingPressure,
            ),
            _deviation(
              FinancialIntelligenceDeviationType.flexibleSpendingPressure,
            ),
            _deviation(
              FinancialIntelligenceDeviationType.discretionarySpendingPressure,
            ),
            _deviation(FinancialIntelligenceDeviationType.assetBuildingSignal),
            _deviation(FinancialIntelligenceDeviationType.debtReductionSignal),
            _deviation(
              FinancialIntelligenceDeviationType.contextRequiredWarning,
            ),
            _deviation(
              FinancialIntelligenceDeviationType.unresolvedBehaviorWarning,
            ),
          ],
        ),
      );

      expect(
        problems.hasProblem(
          FinancialIntelligenceProblemType.ordinarySpendingPressure,
        ),
        isTrue,
      );
      expect(
        problems.hasProblem(
          FinancialIntelligenceProblemType.mandatoryCostPressure,
        ),
        isTrue,
      );
      expect(
        problems.hasProblem(
          FinancialIntelligenceProblemType.reducibleSpendingPressure,
        ),
        isTrue,
      );
      expect(
        problems.hasProblem(
          FinancialIntelligenceProblemType.discretionarySpendingPressure,
        ),
        isTrue,
      );
      expect(
        problems.hasProblem(
          FinancialIntelligenceProblemType.positiveAssetBuildingSignal,
        ),
        isTrue,
      );
      expect(
        problems.hasProblem(
          FinancialIntelligenceProblemType.debtReductionSignal,
        ),
        isTrue,
      );
      expect(
        problems.hasProblem(
          FinancialIntelligenceProblemType.transactionContextRequired,
        ),
        isTrue,
      );
      expect(
        problems.hasProblem(
          FinancialIntelligenceProblemType.classificationCoverageGap,
        ),
        isTrue,
      );
    });

    test('asset building is a positive signal and not a warning problem', () {
      final problems = service.detect(
        FinancialIntelligenceDeviationsSnapshot(
          deviations: [
            _deviation(
              FinancialIntelligenceDeviationType.assetBuildingSignal,
              isWarning: false,
            ),
          ],
        ),
      );

      final problem = problems
          .problemsFor(
            FinancialIntelligenceProblemType.positiveAssetBuildingSignal,
          )
          .single;

      expect(problem.isPositiveSignal, isTrue);
      expect(problem.isWarning, isFalse);
      expect(problem.impact, FinancialProblemImpact.savingsCapacity);
    });

    test('debt reduction is a positive neutral signal', () {
      final problems = service.detect(
        FinancialIntelligenceDeviationsSnapshot(
          deviations: [
            _deviation(
              FinancialIntelligenceDeviationType.debtReductionSignal,
              isWarning: false,
            ),
          ],
        ),
      );

      final problem = problems
          .problemsFor(FinancialIntelligenceProblemType.debtReductionSignal)
          .single;

      expect(problem.isPositiveSignal, isTrue);
      expect(problem.isWarning, isFalse);
      expect(problem.impact, FinancialProblemImpact.savingsCapacity);
    });

    test('context required is a warning context problem', () {
      final problems = service.detect(
        FinancialIntelligenceDeviationsSnapshot(
          deviations: [
            _deviation(
              FinancialIntelligenceDeviationType.contextRequiredWarning,
            ),
          ],
        ),
      );

      final problem = problems
          .problemsFor(
            FinancialIntelligenceProblemType.transactionContextRequired,
          )
          .single;

      expect(problem.isWarning, isTrue);
      expect(problem.impact, FinancialProblemImpact.dataReliability);
    });

    test('unresolved behavior is a classification coverage problem', () {
      final problems = service.detect(
        FinancialIntelligenceDeviationsSnapshot(
          deviations: [
            _deviation(
              FinancialIntelligenceDeviationType.unresolvedBehaviorWarning,
            ),
          ],
        ),
      );

      final problem = problems
          .problemsFor(
            FinancialIntelligenceProblemType.classificationCoverageGap,
          )
          .single;

      expect(problem.isWarning, isTrue);
      expect(problem.isDiagnosticsOnly, isTrue);
      expect(problem.impact, FinancialProblemImpact.dataReliability);
    });
  });
}

FinancialIntelligenceDeviation _deviation(
  FinancialIntelligenceDeviationType type, {
  bool isWarning = true,
}) {
  final period = FinancialModelPeriod(
    start: DateTime.utc(2035, 6),
    end: DateTime.utc(2035, 7),
  );

  return FinancialIntelligenceDeviation(
    deviationId: 'financial.intelligence.deviation.${type.name}',
    type: type,
    actualValue: 1,
    expectedValue: 0,
    deviationAmount: 1,
    unit: FinancialModelUnit.ratio,
    period: period,
    severity: FinancialDeviationSeverity.medium,
    sourceModelTypes: const [
      FinancialIntelligenceModelType.ordinarySpendingRatio,
    ],
    isWarning: isWarning,
    isDiagnosticsOnly: true,
  );
}
