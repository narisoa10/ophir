import 'build_financial_runtime_recommendation_configuration_source.dart';
import 'financial_runtime_recommendation_config.dart';
import 'financial_runtime_recommendation_configuration_source.dart';

final class LocalFinancialRuntimeRecommendationConfigurationSource
    implements FinancialRuntimeRecommendationConfigurationSource {
  const LocalFinancialRuntimeRecommendationConfigurationSource({
    this.buildSource =
        const BuildFinancialRuntimeRecommendationConfigurationSource(),
  });

  final FinancialRuntimeRecommendationConfigurationSource buildSource;

  @override
  FinancialRuntimeRecommendationConfig load() {
    return buildSource.load();
  }
}
