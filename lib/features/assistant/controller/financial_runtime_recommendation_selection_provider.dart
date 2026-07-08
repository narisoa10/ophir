import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/result.dart';
import '../domain/entities/financial_recommendation.dart';
import '../domain/entities/financial_recommendation_comparison_read_model.dart';
import '../domain/entities/financial_runtime_recommendation_mode.dart';
import '../domain/entities/financial_runtime_recommendation_selection.dart';
import '../domain/services/financial_runtime_recommendation_policy.dart';
import 'financial_recommendation_comparison_provider.dart';
import 'legacy_assistant_recommendation_provider.dart';

final financialRuntimeRecommendationModeProvider =
    Provider<FinancialRuntimeRecommendationMode>(
      (ref) => FinancialRuntimeRecommendationMode.intelligenceAllowlist,
    );

final financialRuntimeRecommendationSelectionProvider =
    FutureProvider<Result<FinancialRuntimeRecommendationSelection>>((
      ref,
    ) async {
      final mode = ref.watch(financialRuntimeRecommendationModeProvider);
      final legacyResult = await ref.watch(
        legacyAssistantRecommendationProvider.future,
      );

      if (legacyResult case Failure<FinancialRecommendation?>(:final failure)) {
        return Failure(failure);
      }

      final legacyRecommendation =
          (legacyResult as Success<FinancialRecommendation?>).value;

      if (mode != FinancialRuntimeRecommendationMode.intelligenceAllowlist) {
        return Success(
          const FinancialRuntimeRecommendationPolicy().select(
            mode: mode,
            legacyRecommendation: legacyRecommendation,
            comparison: null,
          ),
        );
      }

      final comparisonResult = await ref.watch(
        financialRecommendationComparisonProvider.future,
      );
      final comparison =
          comparisonResult
              is Success<FinancialRecommendationComparisonReadModel>
          ? comparisonResult.value
          : null;

      return Success(
        const FinancialRuntimeRecommendationPolicy().select(
          mode: mode,
          legacyRecommendation: legacyRecommendation,
          comparison: comparison,
        ),
      );
    });
