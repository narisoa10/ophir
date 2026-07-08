import 'financial_runtime_recommendation_config.dart';
import 'financial_runtime_recommendation_configuration_source.dart';
import 'financial_runtime_recommendation_mode.dart';

final class BuildFinancialRuntimeRecommendationConfigurationSource
    implements FinancialRuntimeRecommendationConfigurationSource {
  const BuildFinancialRuntimeRecommendationConfigurationSource({
    String runtimeMode = _environmentRuntimeMode,
  }) : _runtimeMode = runtimeMode;

  static const environmentKey = 'FINANCIAL_RUNTIME_MODE';
  static const _environmentRuntimeMode = String.fromEnvironment(environmentKey);
  static const _defaultMode =
      FinancialRuntimeRecommendationMode.intelligenceAllowlist;

  final String _runtimeMode;

  @override
  FinancialRuntimeRecommendationConfig load() {
    return FinancialRuntimeRecommendationConfig(mode: _parseMode(_runtimeMode));
  }

  FinancialRuntimeRecommendationMode _parseMode(String value) {
    return switch (value) {
      'legacy' => FinancialRuntimeRecommendationMode.legacy,
      'intelligenceAllowlist' =>
        FinancialRuntimeRecommendationMode.intelligenceAllowlist,
      'shadowOnly' => FinancialRuntimeRecommendationMode.shadowOnly,
      _ => _defaultMode,
    };
  }
}
