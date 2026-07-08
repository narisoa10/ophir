import 'financial_runtime_recommendation_config.dart';
import 'financial_runtime_recommendation_configuration_source.dart';
import 'financial_runtime_recommendation_mode.dart';

final class LocalFinancialRuntimeRecommendationConfigurationSource
    implements FinancialRuntimeRecommendationConfigurationSource {
  const LocalFinancialRuntimeRecommendationConfigurationSource();

  @override
  FinancialRuntimeRecommendationConfig load() {
    return const FinancialRuntimeRecommendationConfig(
      mode: FinancialRuntimeRecommendationMode.intelligenceAllowlist,
    );
  }
}
