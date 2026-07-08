import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ophir/core/errors/result.dart';
import 'package:ophir/features/assistant/controller/financial_intelligence_problems_provider.dart';
import 'package:ophir/features/assistant/controller/financial_intelligence_recommendation_diagnostics_provider.dart';
import 'package:ophir/features/assistant/domain/entities/financial_intelligence_problem.dart';
import 'package:ophir/features/assistant/domain/entities/financial_intelligence_problem_type.dart';
import 'package:ophir/features/assistant/domain/entities/financial_intelligence_problems_snapshot.dart';
import 'package:ophir/features/assistant/domain/entities/financial_intelligence_recommendation_type.dart';
import 'package:ophir/features/assistant/domain/entities/financial_model_period.dart';
import 'package:ophir/features/assistant/domain/entities/financial_problem_impact.dart';
import 'package:ophir/features/assistant/domain/entities/financial_problem_severity.dart';

void main() {
  group('financialIntelligenceRecommendationDiagnosticsProvider', () {
    test('builds diagnostics from shadow problems provider', () async {
      final container = ProviderContainer(
        overrides: [
          financialIntelligenceProblemsProvider.overrideWith(
            (ref) async => Success(
              FinancialIntelligenceProblemsSnapshot(
                problems: [
                  _problem(
                    FinancialIntelligenceProblemType.ordinarySpendingPressure,
                  ),
                ],
              ),
            ),
          ),
        ],
      );
      addTearDown(container.dispose);

      final result = await container.read(
        financialIntelligenceRecommendationDiagnosticsProvider.future,
      );
      final snapshot = switch (result) {
        Success(:final value) => value,
        Failure() => fail('Expected recommendation diagnostics snapshot'),
      };

      expect(
        snapshot.hasRecommendation(
          FinancialIntelligenceRecommendationType
              .reviewOrdinarySpendingStructure,
        ),
        isTrue,
      );
    });

    test('does not read runtime recommendation or Dashboard providers', () {
      final source = File(
        'lib/features/assistant/controller/'
        'financial_intelligence_recommendation_diagnostics_provider.dart',
      ).readAsStringSync();

      expect(source, contains('financialIntelligenceProblemsProvider'));
      expect(source, isNot(contains('assistantDashboardBriefingProvider')));
      expect(source, isNot(contains('Dashboard')));
      expect(source, isNot(contains('FinancialDecisionOptionsService')));
      expect(source, isNot(contains('FinancialRecommendationService')));
      expect(source, isNot(contains('FinancialExplanationService')));
    });

    test('is not connected to Assistant briefing or Dashboard UI', () {
      final briefingServiceSource = File(
        'lib/features/assistant/domain/services/'
        'assistant_dashboard_briefing_service.dart',
      ).readAsStringSync();
      final briefingProviderSource = File(
        'lib/features/assistant/controller/'
        'assistant_dashboard_briefing_provider.dart',
      ).readAsStringSync();
      final dashboardAdapterSource = File(
        'lib/features/dashboard/presentation/adapters/'
        'dashboard_presentation_adapter.dart',
      ).readAsStringSync();

      expect(
        briefingServiceSource,
        isNot(
          contains('financialIntelligenceRecommendationDiagnosticsProvider'),
        ),
      );
      expect(
        briefingProviderSource,
        isNot(
          contains('financialIntelligenceRecommendationDiagnosticsProvider'),
        ),
      );
      expect(
        dashboardAdapterSource,
        isNot(contains('FinancialIntelligenceRecommendation')),
      );
    });
  });
}

FinancialIntelligenceProblem _problem(FinancialIntelligenceProblemType type) {
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
    isPositiveSignal: false,
    isWarning: true,
    isDiagnosticsOnly: true,
  );
}
