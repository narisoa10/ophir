import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/result.dart';
import '../domain/entities/financial_intelligence_recommendation_diagnostics_snapshot.dart';
import '../domain/entities/financial_recommendation.dart';
import '../domain/entities/financial_recommendation_comparison_read_model.dart';
import '../domain/services/financial_recommendation_comparison_service.dart';
import 'current_assistant_recommendation_provider.dart';
import 'financial_intelligence_recommendation_diagnostics_provider.dart';

final financialRecommendationComparisonProvider =
    FutureProvider<Result<FinancialRecommendationComparisonReadModel>>((
      ref,
    ) async {
      final recommendationResult = await ref.watch(
        currentAssistantRecommendationProvider.future,
      );
      final diagnosticsResult = await ref.watch(
        financialIntelligenceRecommendationDiagnosticsProvider.future,
      );

      if (recommendationResult
          case Failure<FinancialRecommendation?>(:final failure)) {
        return Failure(failure);
      }
      if (diagnosticsResult
          case Failure<FinancialIntelligenceRecommendationDiagnosticsSnapshot>(
            :final failure,
          )) {
        return Failure(failure);
      }

      final recommendation =
          (recommendationResult as Success<FinancialRecommendation?>).value;
      final diagnostics =
          (diagnosticsResult
                  as Success<
                    FinancialIntelligenceRecommendationDiagnosticsSnapshot
                  >)
              .value;

      return Success(
        const FinancialRecommendationComparisonService().build(
          legacyRecommendation: recommendation,
          shadowDiagnostics: diagnostics,
        ),
      );
    });
