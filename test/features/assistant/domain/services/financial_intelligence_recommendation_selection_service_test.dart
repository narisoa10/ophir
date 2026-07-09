import 'package:flutter_test/flutter_test.dart';
import 'package:ophir/features/assistant/domain/entities/financial_intelligence_decision_option.dart';
import 'package:ophir/features/assistant/domain/entities/financial_intelligence_decision_option_type.dart';
import 'package:ophir/features/assistant/domain/entities/financial_intelligence_decision_options_snapshot.dart';
import 'package:ophir/features/assistant/domain/entities/financial_intelligence_problem_type.dart';
import 'package:ophir/features/assistant/domain/entities/financial_intelligence_recommendation_selection_reason.dart';
import 'package:ophir/features/assistant/domain/entities/financial_model_period.dart';
import 'package:ophir/features/assistant/domain/services/financial_intelligence_recommendation_selection_service.dart';

void main() {
  const service = FinancialIntelligenceRecommendationSelectionService();

  group('FinancialIntelligenceRecommendationSelectionService', () {
    test('selects deterministically by priority', () {
      final asset = _option(
        FinancialIntelligenceDecisionOptionType.maintainAssetBuildingMomentum,
        idSuffix: 'z',
      );
      final context = _option(
        FinancialIntelligenceDecisionOptionType.reviewTransactionContext,
        idSuffix: 'b',
      );
      final contextEarlierId = _option(
        FinancialIntelligenceDecisionOptionType.reviewTransactionContext,
        idSuffix: 'a',
      );
      final snapshot = service.select(
        FinancialIntelligenceDecisionOptionsSnapshot(
          options: [asset, context, contextEarlierId],
        ),
      );

      expect(snapshot.selectedOption, same(contextEarlierId));
      expect(
        snapshot.selectionReason,
        FinancialIntelligenceRecommendationSelectionReason.priorityOrder,
      );
    });

    test('context review wins over spending', () {
      final spending = _option(
        FinancialIntelligenceDecisionOptionType.reduceReducibleSpending,
      );
      final context = _option(
        FinancialIntelligenceDecisionOptionType.reviewTransactionContext,
      );

      final snapshot = service.select(
        FinancialIntelligenceDecisionOptionsSnapshot(
          options: [spending, context],
        ),
      );

      expect(snapshot.selectedOption, same(context));
    });

    test('coverage wins over spending', () {
      final ordinary = _option(
        FinancialIntelligenceDecisionOptionType.reviewOrdinarySpendingStructure,
      );
      final coverage = _option(
        FinancialIntelligenceDecisionOptionType.improveCategoryCoverage,
      );

      final snapshot = service.select(
        FinancialIntelligenceDecisionOptionsSnapshot(
          options: [ordinary, coverage],
        ),
      );

      expect(snapshot.selectedOption, same(coverage));
    });

    test('mandatory wins over ordinary and reducible', () {
      final ordinary = _option(
        FinancialIntelligenceDecisionOptionType.reviewOrdinarySpendingStructure,
      );
      final reducible = _option(
        FinancialIntelligenceDecisionOptionType.reduceReducibleSpending,
      );
      final mandatory = _option(
        FinancialIntelligenceDecisionOptionType.reviewMandatoryCosts,
      );

      final snapshot = service.select(
        FinancialIntelligenceDecisionOptionsSnapshot(
          options: [ordinary, reducible, mandatory],
        ),
      );

      expect(snapshot.selectedOption, same(mandatory));
    });

    test('positive signals are lower priority than corrective options', () {
      final debt = _option(
        FinancialIntelligenceDecisionOptionType.maintainDebtReductionMomentum,
        isPositiveSignal: true,
        isWarning: false,
      );
      final asset = _option(
        FinancialIntelligenceDecisionOptionType.maintainAssetBuildingMomentum,
        isPositiveSignal: true,
        isWarning: false,
      );
      final discretionary = _option(
        FinancialIntelligenceDecisionOptionType
            .deferOrReduceDiscretionarySpending,
      );

      final snapshot = service.select(
        FinancialIntelligenceDecisionOptionsSnapshot(
          options: [asset, debt, discretionary],
        ),
      );

      expect(snapshot.selectedOption, same(discretionary));
      expect(snapshot.rejectedOptions, [debt, asset]);
    });

    test('rejectedOptions are populated in deterministic order', () {
      final reducible = _option(
        FinancialIntelligenceDecisionOptionType.reduceReducibleSpending,
      );
      final mandatory = _option(
        FinancialIntelligenceDecisionOptionType.reviewMandatoryCosts,
      );
      final coverage = _option(
        FinancialIntelligenceDecisionOptionType.improveCategoryCoverage,
      );

      final snapshot = service.select(
        FinancialIntelligenceDecisionOptionsSnapshot(
          options: [reducible, mandatory, coverage],
        ),
      );

      expect(snapshot.selectedOption, same(coverage));
      expect(snapshot.rejectedOptions, [mandatory, reducible]);
      expect(snapshot.isDiagnosticsOnly, isTrue);
    });

    test('empty input returns diagnostics-only no option selection', () {
      final snapshot = service.select(
        FinancialIntelligenceDecisionOptionsSnapshot(options: const []),
      );

      expect(snapshot.selectedOption, isNull);
      expect(snapshot.rejectedOptions, isEmpty);
      expect(
        snapshot.selectionReason,
        FinancialIntelligenceRecommendationSelectionReason.noAvailableOptions,
      );
      expect(snapshot.isDiagnosticsOnly, isTrue);
    });
  });
}

FinancialIntelligenceDecisionOption _option(
  FinancialIntelligenceDecisionOptionType type, {
  String idSuffix = 'default',
  bool isPositiveSignal = false,
  bool isWarning = true,
}) {
  final period = FinancialModelPeriod(
    start: DateTime.utc(2035, 6),
    end: DateTime.utc(2035, 7),
  );

  return FinancialIntelligenceDecisionOption(
    optionId: 'financial.intelligence.decisionOption.${type.name}.$idSuffix',
    type: type,
    period: period,
    sourceProblemIds: ['problem.${type.name}'],
    sourceProblemTypes: const [
      FinancialIntelligenceProblemType.ordinarySpendingPressure,
    ],
    parityMetric: null,
    parityStatus: null,
    legacyModelValue: null,
    intelligenceModelValue: null,
    isPositiveSignal: isPositiveSignal,
    isWarning: isWarning,
    isDiagnosticsOnly: true,
  );
}
