import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/entities/financial_runtime_recommendation_config.dart';
import '../domain/entities/financial_runtime_recommendation_configuration_source.dart';
import '../domain/entities/local_financial_runtime_recommendation_configuration_source.dart';

final financialRuntimeRecommendationConfigurationSourceProvider =
    Provider<FinancialRuntimeRecommendationConfigurationSource>(
      (ref) => const LocalFinancialRuntimeRecommendationConfigurationSource(),
    );

final financialRuntimeRecommendationConfigProvider =
    Provider<FinancialRuntimeRecommendationConfig>(
      (ref) => ref
          .watch(financialRuntimeRecommendationConfigurationSourceProvider)
          .load(),
    );
