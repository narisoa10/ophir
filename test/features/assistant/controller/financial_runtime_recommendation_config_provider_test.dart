import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ophir/features/assistant/controller/financial_runtime_recommendation_config_provider.dart';
import 'package:ophir/features/assistant/domain/entities/build_financial_runtime_recommendation_configuration_source.dart';
import 'package:ophir/features/assistant/domain/entities/financial_runtime_recommendation_config.dart';
import 'package:ophir/features/assistant/domain/entities/financial_runtime_recommendation_configuration_source.dart';
import 'package:ophir/features/assistant/domain/entities/financial_runtime_recommendation_mode.dart';
import 'package:ophir/features/assistant/domain/entities/local_financial_runtime_recommendation_configuration_source.dart';

void main() {
  group('financialRuntimeRecommendationConfigProvider', () {
    test('valid build values map correctly', () {
      final cases = {
        'legacy': FinancialRuntimeRecommendationMode.legacy,
        'intelligenceAllowlist':
            FinancialRuntimeRecommendationMode.intelligenceAllowlist,
        'shadowOnly': FinancialRuntimeRecommendationMode.shadowOnly,
      };

      for (final entry in cases.entries) {
        final source = BuildFinancialRuntimeRecommendationConfigurationSource(
          runtimeMode: entry.key,
        );

        final config = source.load();

        expect(config.mode, entry.value, reason: entry.key);
      }
    });

    test('invalid build value falls back to default', () {
      const source = BuildFinancialRuntimeRecommendationConfigurationSource(
        runtimeMode: 'unsupported',
      );

      final config = source.load();

      expect(
        config.mode,
        FinancialRuntimeRecommendationMode.intelligenceAllowlist,
      );
    });

    test('missing build value falls back to default', () {
      const source = BuildFinancialRuntimeRecommendationConfigurationSource(
        runtimeMode: '',
      );

      final config = source.load();

      expect(
        config.mode,
        FinancialRuntimeRecommendationMode.intelligenceAllowlist,
      );
    });

    test('local source returns expected config', () {
      const source = LocalFinancialRuntimeRecommendationConfigurationSource();

      final config = source.load();

      expect(
        config.mode,
        FinancialRuntimeRecommendationMode.intelligenceAllowlist,
      );
    });

    test('local source uses build configuration', () {
      const source = LocalFinancialRuntimeRecommendationConfigurationSource(
        buildSource: BuildFinancialRuntimeRecommendationConfigurationSource(
          runtimeMode: 'legacy',
        ),
      );

      final config = source.load();

      expect(config.mode, FinancialRuntimeRecommendationMode.legacy);
    });

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

    test('config provider reads configuration from source provider', () {
      final container = ProviderContainer(
        overrides: [
          financialRuntimeRecommendationConfigurationSourceProvider
              .overrideWithValue(
                const _FakeFinancialRuntimeRecommendationConfigurationSource(
                  FinancialRuntimeRecommendationConfig(
                    mode: FinancialRuntimeRecommendationMode.legacy,
                  ),
                ),
              ),
        ],
      );
      addTearDown(container.dispose);

      final config = container.read(
        financialRuntimeRecommendationConfigProvider,
      );

      expect(config.mode, FinancialRuntimeRecommendationMode.legacy);
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

final class _FakeFinancialRuntimeRecommendationConfigurationSource
    implements FinancialRuntimeRecommendationConfigurationSource {
  const _FakeFinancialRuntimeRecommendationConfigurationSource(this.config);

  final FinancialRuntimeRecommendationConfig config;

  @override
  FinancialRuntimeRecommendationConfig load() {
    return config;
  }
}
