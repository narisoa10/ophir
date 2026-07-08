import 'package:flutter_test/flutter_test.dart';
import 'package:ophir/features/assistant/domain/entities/financial_intelligence_problem.dart';
import 'package:ophir/features/assistant/domain/entities/financial_intelligence_problem_type.dart';
import 'package:ophir/features/assistant/domain/entities/financial_intelligence_problems_snapshot.dart';
import 'package:ophir/features/assistant/domain/entities/financial_intelligence_recommendation_type.dart';
import 'package:ophir/features/assistant/domain/entities/financial_model_period.dart';
import 'package:ophir/features/assistant/domain/entities/financial_problem_impact.dart';
import 'package:ophir/features/assistant/domain/entities/financial_problem_severity.dart';
import 'package:ophir/features/assistant/domain/services/financial_intelligence_recommendation_diagnostics_service.dart';

void main() {
  const service = FinancialIntelligenceRecommendationDiagnosticsService();

  group('FinancialIntelligenceRecommendationDiagnosticsService', () {
    test('maps every shadow problem to its recommendation diagnostic', () {
      final snapshot = service.build(
        FinancialIntelligenceProblemsSnapshot(
          problems: [
            _problem(FinancialIntelligenceProblemType.ordinarySpendingPressure),
            _problem(FinancialIntelligenceProblemType.mandatoryCostPressure),
            _problem(
              FinancialIntelligenceProblemType.reducibleSpendingPressure,
            ),
            _problem(
              FinancialIntelligenceProblemType.discretionarySpendingPressure,
            ),
            _problem(
              FinancialIntelligenceProblemType.positiveAssetBuildingSignal,
              isPositiveSignal: true,
              isWarning: false,
            ),
            _problem(
              FinancialIntelligenceProblemType.debtReductionSignal,
              isPositiveSignal: true,
              isWarning: false,
            ),
            _problem(
              FinancialIntelligenceProblemType.transactionContextRequired,
            ),
            _problem(
              FinancialIntelligenceProblemType.classificationCoverageGap,
            ),
          ],
        ),
      );

      expect(
        snapshot.hasRecommendation(
          FinancialIntelligenceRecommendationType
              .reviewOrdinarySpendingStructure,
        ),
        isTrue,
      );
      expect(
        snapshot.hasRecommendation(
          FinancialIntelligenceRecommendationType.reviewMandatoryCosts,
        ),
        isTrue,
      );
      expect(
        snapshot.hasRecommendation(
          FinancialIntelligenceRecommendationType.reduceReducibleSpending,
        ),
        isTrue,
      );
      expect(
        snapshot.hasRecommendation(
          FinancialIntelligenceRecommendationType
              .deferOrReduceDiscretionarySpending,
        ),
        isTrue,
      );
      expect(
        snapshot.hasRecommendation(
          FinancialIntelligenceRecommendationType.maintainAssetBuildingMomentum,
        ),
        isTrue,
      );
      expect(
        snapshot.hasRecommendation(
          FinancialIntelligenceRecommendationType.maintainDebtReductionMomentum,
        ),
        isTrue,
      );
      expect(
        snapshot.hasRecommendation(
          FinancialIntelligenceRecommendationType.reviewTransactionContext,
        ),
        isTrue,
      );
      expect(
        snapshot.hasRecommendation(
          FinancialIntelligenceRecommendationType.improveCategoryCoverage,
        ),
        isTrue,
      );
    });

    test('asset building recommendation is a positive signal', () {
      final snapshot = service.build(
        FinancialIntelligenceProblemsSnapshot(
          problems: [
            _problem(
              FinancialIntelligenceProblemType.positiveAssetBuildingSignal,
              isPositiveSignal: true,
              isWarning: false,
            ),
          ],
        ),
      );

      final recommendation = snapshot
          .recommendationsFor(
            FinancialIntelligenceRecommendationType
                .maintainAssetBuildingMomentum,
          )
          .single;

      expect(recommendation.isPositiveSignal, isTrue);
      expect(recommendation.isWarning, isFalse);
    });

    test('debt reduction recommendation is positive neutral signal', () {
      final snapshot = service.build(
        FinancialIntelligenceProblemsSnapshot(
          problems: [
            _problem(
              FinancialIntelligenceProblemType.debtReductionSignal,
              isPositiveSignal: true,
              isWarning: false,
            ),
          ],
        ),
      );

      final recommendation = snapshot
          .recommendationsFor(
            FinancialIntelligenceRecommendationType
                .maintainDebtReductionMomentum,
          )
          .single;

      expect(recommendation.isPositiveSignal, isTrue);
      expect(recommendation.isWarning, isFalse);
    });

    test('context required maps to context-review diagnostic', () {
      final snapshot = service.build(
        FinancialIntelligenceProblemsSnapshot(
          problems: [
            _problem(
              FinancialIntelligenceProblemType.transactionContextRequired,
            ),
          ],
        ),
      );

      final recommendation = snapshot
          .recommendationsFor(
            FinancialIntelligenceRecommendationType.reviewTransactionContext,
          )
          .single;

      expect(recommendation.isWarning, isTrue);
      expect(recommendation.isDiagnosticsOnly, isTrue);
    });

    test('classification coverage maps to category coverage diagnostic', () {
      final snapshot = service.build(
        FinancialIntelligenceProblemsSnapshot(
          problems: [
            _problem(
              FinancialIntelligenceProblemType.classificationCoverageGap,
            ),
          ],
        ),
      );

      final recommendation = snapshot
          .recommendationsFor(
            FinancialIntelligenceRecommendationType.improveCategoryCoverage,
          )
          .single;

      expect(recommendation.sourceProblemTypes, [
        FinancialIntelligenceProblemType.classificationCoverageGap,
      ]);
    });
  });
}

FinancialIntelligenceProblem _problem(
  FinancialIntelligenceProblemType type, {
  bool isPositiveSignal = false,
  bool isWarning = true,
}) {
  final period = FinancialModelPeriod(
    start: DateTime.utc(2035, 6),
    end: DateTime.utc(2035, 7),
  );

  return FinancialIntelligenceProblem(
    problemId: 'financial.intelligence.problem.${type.name}',
    type: type,
    period: period,
    severity: FinancialProblemSeverity.medium,
    impact: FinancialProblemImpact.spendingFlexibility,
    sourceDeviationIds: const ['source-deviation'],
    sourceDeviationTypes: const [],
    isPositiveSignal: isPositiveSignal,
    isWarning: isWarning,
    isDiagnosticsOnly: true,
  );
}
