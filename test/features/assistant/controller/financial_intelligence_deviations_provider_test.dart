import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ophir/core/errors/result.dart';
import 'package:ophir/features/assistant/controller/financial_intelligence_deviations_provider.dart';
import 'package:ophir/features/assistant/controller/financial_intelligence_diagnostics_provider.dart';
import 'package:ophir/features/assistant/domain/entities/financial_behavior_compatibility_output.dart';
import 'package:ophir/features/assistant/domain/entities/financial_behavior_facts_snapshot.dart';
import 'package:ophir/features/assistant/domain/entities/financial_behavior_totals.dart';
import 'package:ophir/features/assistant/domain/entities/financial_intelligence_deviation_type.dart';
import 'package:ophir/features/assistant/domain/entities/financial_intelligence_diagnostics_read_model.dart';
import 'package:ophir/features/assistant/domain/entities/financial_intelligence_model.dart';
import 'package:ophir/features/assistant/domain/entities/financial_intelligence_models_snapshot.dart';
import 'package:ophir/features/assistant/domain/entities/financial_intelligence_model_type.dart';
import 'package:ophir/features/assistant/domain/entities/financial_model_period.dart';

void main() {
  group('financialIntelligenceDeviationsProvider', () {
    test('builds shadow deviations from diagnostics provider', () async {
      final container = ProviderContainer(
        overrides: [
          financialIntelligenceDiagnosticsProvider.overrideWith(
            (ref) async => Success(
              _diagnostics(
                values: {
                  FinancialIntelligenceModelType.ordinarySpendingRatio: 0.80,
                },
              ),
            ),
          ),
        ],
      );
      addTearDown(container.dispose);

      final result = await container.read(
        financialIntelligenceDeviationsProvider.future,
      );
      final snapshot = switch (result) {
        Success(:final value) => value,
        Failure() => fail('Expected intelligence deviations snapshot'),
      };

      expect(
        snapshot.hasDeviation(
          FinancialIntelligenceDeviationType.ordinarySpendingPressure,
        ),
        isTrue,
      );
    });

    test('does not read Assistant briefing Dashboard or recommendations', () {
      final source = File(
        'lib/features/assistant/controller/financial_intelligence_deviations_provider.dart',
      ).readAsStringSync();

      expect(source, contains('financialIntelligenceDiagnosticsProvider'));
      expect(source, isNot(contains('assistantDashboardBriefingProvider')));
      expect(source, isNot(contains('Dashboard')));
      expect(source, isNot(contains('Recommendation')));
    });
  });
}

FinancialIntelligenceDiagnosticsReadModel _diagnostics({
  Map<FinancialIntelligenceModelType, double> values = const {},
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
      totals: const FinancialBehaviorTotals(
        legacyExpenseTotal: 0,
        ordinarySpendingTotal: 0,
        assetBuildingTotal: 0,
        debtReductionTotal: 0,
        cashMovementTotal: 0,
        dataAdjustmentTotal: 0,
        contextRequiredTotal: 0,
        behavioralSavingsTotal: 0,
        legacyVsIntelligenceDifference: 0,
        unresolvedCount: 0,
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
