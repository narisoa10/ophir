import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ophir/features/assistant/controller/financial_runtime_recommendation_config_provider.dart';
import 'package:ophir/features/assistant/domain/entities/financial_runtime_recommendation_config.dart';
import 'package:ophir/features/assistant/domain/entities/financial_runtime_recommendation_mode.dart';

void main() {
  group('financialRuntimeRecommendationConfigProvider', () {
    test('default config returns expected mode', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final config = container.read(
        financialRuntimeRecommendationConfigProvider,
      );

      expect(
        config.mode,
        FinancialRuntimeRecommendationMode.intelligenceAllowlist,
      );
    });

    test('config override changes runtime mode', () {
      final container = ProviderContainer(
        overrides: [
          financialRuntimeRecommendationConfigProvider.overrideWithValue(
            const FinancialRuntimeRecommendationConfig(
              mode: FinancialRuntimeRecommendationMode.shadowOnly,
            ),
          ),
        ],
      );
      addTearDown(container.dispose);

      final config = container.read(
        financialRuntimeRecommendationConfigProvider,
      );

      expect(config.mode, FinancialRuntimeRecommendationMode.shadowOnly);
    });
  });
}
