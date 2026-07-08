import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/entities/financial_runtime_recommendation_config.dart';
import '../domain/entities/financial_runtime_recommendation_mode.dart';

final financialRuntimeRecommendationConfigProvider =
    Provider<FinancialRuntimeRecommendationConfig>(
      (ref) => const FinancialRuntimeRecommendationConfig(
        mode: FinancialRuntimeRecommendationMode.intelligenceAllowlist,
      ),
    );
