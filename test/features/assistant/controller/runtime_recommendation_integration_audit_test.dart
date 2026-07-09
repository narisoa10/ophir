import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('runtime recommendation integration audit', () {
    test(
      'public Assistant briefing gets recommendation through runtime boundary',
      () {
        final source = File(
          'lib/features/assistant/controller/assistant_dashboard_briefing_provider.dart',
        ).readAsStringSync();

        expect(source, contains('currentAssistantRecommendationProvider'));
        expect(
          source,
          isNot(contains('legacyAssistantRecommendationProvider')),
        );
        expect(source, isNot(contains('FinancialRecommendationService')));
        expect(
          source,
          isNot(contains('financialRecommendationComparisonProvider')),
        );
        expect(
          source,
          isNot(
            contains('financialIntelligenceRecommendationDiagnosticsProvider'),
          ),
        );
        expect(
          source,
          isNot(
            contains('financialIntelligenceRecommendationSelectionProvider'),
          ),
        );
        expect(
          source,
          isNot(
            contains('financialIntelligenceRecommendationExplanationProvider'),
          ),
        );
      },
    );

    test('legacy recommendation provider is only policy and comparison input', () {
      final allowedPaths = {
        'lib\\features\\assistant\\controller\\legacy_assistant_recommendation_provider.dart',
        'lib\\features\\assistant\\controller\\financial_recommendation_comparison_provider.dart',
        'lib\\features\\assistant\\controller\\financial_runtime_recommendation_selection_provider.dart',
        'lib\\features\\assistant\\controller\\financial_runtime_shadow_diagnostics_provider.dart',
      };

      final matches = _libMatches('legacyAssistantRecommendationProvider');

      expect(matches.keys.toSet(), allowedPaths);
    });

    test('runtime mode is read through config provider', () {
      final source = File(
        'lib/features/assistant/controller/'
        'financial_runtime_recommendation_selection_provider.dart',
      ).readAsStringSync();

      expect(source, contains('financialRuntimeRecommendationConfigProvider'));
      expect(
        source,
        isNot(contains('financialRuntimeRecommendationModeProvider')),
      );
      expect(
        source,
        isNot(contains('Provider<FinancialRuntimeRecommendationMode>')),
      );
    });

    test('runtime config provider reads through configuration source', () {
      final source = File(
        'lib/features/assistant/controller/'
        'financial_runtime_recommendation_config_provider.dart',
      ).readAsStringSync();

      expect(
        source,
        contains('financialRuntimeRecommendationConfigurationSourceProvider'),
      );
      expect(
        source,
        contains('LocalFinancialRuntimeRecommendationConfigurationSource'),
      );
      expect(
        source,
        isNot(
          contains('FinancialRuntimeRecommendationMode.intelligenceAllowlist'),
        ),
      );
    });

    test('configuration source provider is internal to config provider', () {
      final matches = _libMatches(
        'financialRuntimeRecommendationConfigurationSourceProvider',
      );

      expect(matches.keys.toSet(), {
        'lib\\features\\assistant\\controller\\financial_runtime_recommendation_config_provider.dart',
      });
    });

    test('build source is used only inside local configuration source', () {
      final matches = _libMatches(
        'BuildFinancialRuntimeRecommendationConfigurationSource',
      );

      expect(matches.keys.toSet(), {
        'lib\\features\\assistant\\domain\\entities\\build_financial_runtime_recommendation_configuration_source.dart',
        'lib\\features\\assistant\\domain\\entities\\local_financial_runtime_recommendation_configuration_source.dart',
      });
    });

    test('build source reads only FINANCIAL_RUNTIME_MODE environment key', () {
      final source = File(
        'lib/features/assistant/domain/entities/'
        'build_financial_runtime_recommendation_configuration_source.dart',
      ).readAsStringSync();

      expect(source, contains('String.fromEnvironment'));
      expect(source, contains('FINANCIAL_RUNTIME_MODE'));
      expect(source, contains("'legacy'"));
      expect(source, contains("'intelligenceAllowlist'"));
      expect(source, contains("'shadowOnly'"));
    });

    test('legacy runtime mode provider has been removed from lib', () {
      final matches = _libMatches('financialRuntimeRecommendationModeProvider');

      expect(matches, isEmpty);
    });

    test('comparison provider is not used by Dashboard or UI', () {
      for (final file in [
        ...Directory('lib/features/dashboard').listSync(recursive: true),
        ...Directory('lib/features/operations').listSync(recursive: true),
      ].whereType<File>()) {
        final source = file.readAsStringSync();

        expect(
          source,
          isNot(contains('financialRecommendationComparisonProvider')),
          reason: file.path,
        );
        expect(
          source,
          isNot(contains('FinancialRecommendationComparisonReadModel')),
          reason: file.path,
        );
      }
    });

    test('diagnostics internals use independent input boundary', () {
      final compatibilitySource = File(
        'lib/features/assistant/controller/'
        'financial_behavior_compatibility_output_provider.dart',
      ).readAsStringSync();
      final diagnosticsSource = File(
        'lib/features/assistant/controller/'
        'financial_intelligence_diagnostics_provider.dart',
      ).readAsStringSync();
      final inputSource = File(
        'lib/features/assistant/controller/'
        'financial_intelligence_diagnostics_input_provider.dart',
      ).readAsStringSync();

      expect(
        compatibilitySource,
        contains('financialIntelligenceDiagnosticsInputProvider'),
      );
      expect(
        diagnosticsSource,
        contains('financialIntelligenceDiagnosticsInputProvider'),
      );
      expect(inputSource, contains('financialEvaluationContextProvider'));
      expect(
        compatibilitySource,
        isNot(contains('legacyAssistantDashboardBriefingProvider')),
      );
      expect(
        diagnosticsSource,
        isNot(contains('legacyAssistantDashboardBriefingProvider')),
      );
      expect(
        inputSource,
        isNot(contains('legacyAssistantDashboardBriefingProvider')),
      );
      expect(
        compatibilitySource,
        isNot(contains('assistantDashboardBriefingProvider')),
      );
      expect(
        diagnosticsSource,
        isNot(contains('assistantDashboardBriefingProvider')),
      );
    });

    test('model parity provider is not part of runtime boundary', () {
      final matches = _libMatches('financialIntelligenceModelParityProvider');

      expect(matches.keys.toSet(), {
        'lib\\features\\assistant\\controller\\financial_intelligence_decision_options_provider.dart',
        'lib\\features\\assistant\\controller\\financial_intelligence_recommendation_explanation_provider.dart',
        'lib\\features\\assistant\\controller\\financial_intelligence_model_parity_provider.dart',
      });
    });

    test('decision options provider is not part of runtime boundary', () {
      final matches = _libMatches(
        'financialIntelligenceDecisionOptionsProvider',
      );

      expect(matches.keys.toSet(), {
        'lib\\features\\assistant\\controller\\financial_intelligence_decision_options_provider.dart',
        'lib\\features\\assistant\\controller\\financial_intelligence_recommendation_selection_provider.dart',
      });
    });

    test('recommendation selection provider is not part of runtime boundary', () {
      final matches = _libMatches(
        'financialIntelligenceRecommendationSelectionProvider',
      );

      expect(matches.keys.toSet(), {
        'lib\\features\\assistant\\controller\\financial_intelligence_runtime_recommendation_candidate_provider.dart',
        'lib\\features\\assistant\\controller\\financial_intelligence_recommendation_explanation_provider.dart',
        'lib\\features\\assistant\\controller\\financial_intelligence_recommendation_selection_provider.dart',
      });
    });

    test('recommendation explanation provider is not part of runtime boundary', () {
      final matches = _libMatches(
        'financialIntelligenceRecommendationExplanationProvider',
      );

      expect(matches.keys.toSet(), {
        'lib\\features\\assistant\\controller\\financial_intelligence_runtime_recommendation_candidate_provider.dart',
        'lib\\features\\assistant\\controller\\financial_intelligence_recommendation_explanation_provider.dart',
      });
    });

    test('runtime candidate provider is only used by runtime selection', () {
      final matches = _libMatches(
        'financialIntelligenceRuntimeRecommendationCandidateProvider',
      );

      expect(matches.keys.toSet(), {
        'lib\\features\\assistant\\controller\\financial_intelligence_runtime_recommendation_candidate_provider.dart',
        'lib\\features\\assistant\\controller\\financial_runtime_recommendation_selection_provider.dart',
        'lib\\features\\assistant\\controller\\financial_runtime_shadow_diagnostics_provider.dart',
      });
    });
  });
}

Map<String, List<String>> _libMatches(String pattern) {
  final matches = <String, List<String>>{};

  for (final file in Directory(
    'lib',
  ).listSync(recursive: true).whereType<File>()) {
    final source = file.readAsStringSync();
    if (source.contains(pattern)) {
      matches[file.path] = source
          .split('\n')
          .where((line) => line.contains(pattern))
          .toList(growable: false);
    }
  }

  return matches;
}
