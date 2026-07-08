import 'package:flutter_test/flutter_test.dart';
import 'package:ophir/features/assistant/domain/entities/financial_behavior_compatibility_output.dart';
import 'package:ophir/features/assistant/domain/entities/financial_behavior_facts_snapshot.dart';
import 'package:ophir/features/assistant/domain/entities/financial_behavior_totals.dart';
import 'package:ophir/features/assistant/domain/entities/financial_deviation_severity.dart';
import 'package:ophir/features/assistant/domain/entities/financial_intelligence_deviation_type.dart';
import 'package:ophir/features/assistant/domain/entities/financial_intelligence_diagnostics_read_model.dart';
import 'package:ophir/features/assistant/domain/entities/financial_intelligence_model.dart';
import 'package:ophir/features/assistant/domain/entities/financial_intelligence_models_snapshot.dart';
import 'package:ophir/features/assistant/domain/entities/financial_intelligence_model_type.dart';
import 'package:ophir/features/assistant/domain/entities/financial_model_period.dart';
import 'package:ophir/features/assistant/domain/services/financial_intelligence_deviation_service.dart';

void main() {
  const service = FinancialIntelligenceDeviationService();

  group('FinancialIntelligenceDeviationService', () {
    test('creates pressure deviations from intelligence ratios', () {
      final snapshot = service.detect(
        _diagnostics(
          values: {
            FinancialIntelligenceModelType.ordinarySpendingRatio: 0.80,
            FinancialIntelligenceModelType.mandatoryRatio: 0.70,
            FinancialIntelligenceModelType.flexibleRatio: 0.40,
            FinancialIntelligenceModelType.discretionaryRatio: 0.25,
          },
        ),
      );

      expect(
        snapshot.hasDeviation(
          FinancialIntelligenceDeviationType.ordinarySpendingPressure,
        ),
        isTrue,
      );
      expect(
        snapshot.hasDeviation(
          FinancialIntelligenceDeviationType.mandatorySpendingPressure,
        ),
        isTrue,
      );
      expect(
        snapshot.hasDeviation(
          FinancialIntelligenceDeviationType.flexibleSpendingPressure,
        ),
        isTrue,
      );
      expect(
        snapshot.hasDeviation(
          FinancialIntelligenceDeviationType.discretionarySpendingPressure,
        ),
        isTrue,
      );
    });

    test('does not create pressure deviations at threshold', () {
      final snapshot = service.detect(
        _diagnostics(
          values: {
            FinancialIntelligenceModelType.ordinarySpendingRatio: 0.75,
            FinancialIntelligenceModelType.mandatoryRatio: 0.60,
            FinancialIntelligenceModelType.flexibleRatio: 0.30,
            FinancialIntelligenceModelType.discretionaryRatio: 0.20,
          },
        ),
      );

      expect(snapshot.deviations, isEmpty);
    });

    test('creates asset and debt signals without warning semantics', () {
      final snapshot = service.detect(
        _diagnostics(
          values: {
            FinancialIntelligenceModelType.assetBuildingTotal: 300,
            FinancialIntelligenceModelType.debtReductionTotal: 600,
          },
        ),
      );

      final asset = snapshot
          .deviationsFor(FinancialIntelligenceDeviationType.assetBuildingSignal)
          .single;
      final debt = snapshot
          .deviationsFor(FinancialIntelligenceDeviationType.debtReductionSignal)
          .single;

      expect(asset.isWarning, isFalse);
      expect(debt.isWarning, isFalse);
      expect(asset.isDiagnosticsOnly, isTrue);
      expect(debt.isDiagnosticsOnly, isTrue);
    });

    test('creates context and unresolved warnings', () {
      final snapshot = service.detect(
        _diagnostics(
          values: {
            FinancialIntelligenceModelType.contextRequiredTotal: 500,
          },
          unresolvedCount: 2,
        ),
      );

      final contextWarning = snapshot
          .deviationsFor(
            FinancialIntelligenceDeviationType.contextRequiredWarning,
          )
          .single;
      final unresolvedWarning = snapshot
          .deviationsFor(
            FinancialIntelligenceDeviationType.unresolvedBehaviorWarning,
          )
          .single;

      expect(contextWarning.isWarning, isTrue);
      expect(unresolvedWarning.isWarning, isTrue);
      expect(unresolvedWarning.actualValue, 2);
    });

    test('assigns ratio severity from deviation amount', () {
      final snapshot = service.detect(
        _diagnostics(
          values: {
            FinancialIntelligenceModelType.ordinarySpendingRatio: 0.95,
          },
        ),
      );

      final pressure = snapshot
          .deviationsFor(
            FinancialIntelligenceDeviationType.ordinarySpendingPressure,
          )
          .single;

      expect(pressure.severity, FinancialDeviationSeverity.high);
    });
  });
}

FinancialIntelligenceDiagnosticsReadModel _diagnostics({
  Map<FinancialIntelligenceModelType, double> values = const {},
  int unresolvedCount = 0,
}) {
  final period = FinancialModelPeriod(
    start: DateTime.utc(2035, 6),
    end: DateTime.utc(2035, 7),
  );

  return FinancialIntelligenceDiagnosticsReadModel(
    period: period,
    incomeDenominator: 5000,
    behaviorOutput: FinancialBehaviorCompatibilityOutput(
      snapshot: FinancialBehaviorFactsSnapshot(facts: const []),
      totals: FinancialBehaviorTotals(
        legacyExpenseTotal: 0,
        ordinarySpendingTotal: 0,
        assetBuildingTotal: 0,
        debtReductionTotal: 0,
        cashMovementTotal: 0,
        dataAdjustmentTotal: 0,
        contextRequiredTotal: 0,
        behavioralSavingsTotal: 0,
        legacyVsIntelligenceDifference: 0,
        unresolvedCount: unresolvedCount,
      ),
    ),
    modelsSnapshot: FinancialIntelligenceModelsSnapshot(
      models: [
        for (final type in FinancialIntelligenceModelType.values)
          FinancialIntelligenceModel(
            type: type,
            value: values[type] ?? 0,
            isRatio: _isRatio(type),
          ),
      ],
    ),
  );
}

bool _isRatio(FinancialIntelligenceModelType type) {
  return switch (type) {
    FinancialIntelligenceModelType.ordinarySpendingRatio ||
    FinancialIntelligenceModelType.mandatoryRatio ||
    FinancialIntelligenceModelType.flexibleRatio ||
    FinancialIntelligenceModelType.discretionaryRatio => true,
    _ => false,
  };
}
