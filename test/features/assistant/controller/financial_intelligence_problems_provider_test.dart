import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ophir/core/errors/result.dart';
import 'package:ophir/features/assistant/controller/financial_intelligence_deviations_provider.dart';
import 'package:ophir/features/assistant/controller/financial_intelligence_problems_provider.dart';
import 'package:ophir/features/assistant/domain/entities/financial_deviation_severity.dart';
import 'package:ophir/features/assistant/domain/entities/financial_intelligence_deviation.dart';
import 'package:ophir/features/assistant/domain/entities/financial_intelligence_deviation_type.dart';
import 'package:ophir/features/assistant/domain/entities/financial_intelligence_deviations_snapshot.dart';
import 'package:ophir/features/assistant/domain/entities/financial_intelligence_model_type.dart';
import 'package:ophir/features/assistant/domain/entities/financial_intelligence_problem_type.dart';
import 'package:ophir/features/assistant/domain/entities/financial_model_period.dart';
import 'package:ophir/features/assistant/domain/entities/financial_model_unit.dart';

void main() {
  group('financialIntelligenceProblemsProvider', () {
    test('builds shadow problems from shadow deviations provider', () async {
      final container = ProviderContainer(
        overrides: [
          financialIntelligenceDeviationsProvider.overrideWith(
            (ref) async => Success(
              FinancialIntelligenceDeviationsSnapshot(
                deviations: [
                  _deviation(
                    FinancialIntelligenceDeviationType.ordinarySpendingPressure,
                  ),
                ],
              ),
            ),
          ),
        ],
      );
      addTearDown(container.dispose);

      final result = await container.read(
        financialIntelligenceProblemsProvider.future,
      );
      final snapshot = switch (result) {
        Success(:final value) => value,
        Failure() => fail('Expected intelligence problems snapshot'),
      };

      expect(
        snapshot.hasProblem(
          FinancialIntelligenceProblemType.ordinarySpendingPressure,
        ),
        isTrue,
      );
    });

    test('does not read Assistant briefing Dashboard or recommendations', () {
      final source = File(
        'lib/features/assistant/controller/financial_intelligence_problems_provider.dart',
      ).readAsStringSync();

      expect(source, contains('financialIntelligenceDeviationsProvider'));
      expect(source, isNot(contains('assistantDashboardBriefingProvider')));
      expect(source, isNot(contains('Dashboard')));
      expect(source, isNot(contains('Recommendation')));
    });
  });
}

FinancialIntelligenceDeviation _deviation(
  FinancialIntelligenceDeviationType type,
) {
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
    isWarning: true,
    isDiagnosticsOnly: true,
  );
}
