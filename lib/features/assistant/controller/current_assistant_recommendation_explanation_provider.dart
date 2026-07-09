import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/result.dart';
import '../domain/entities/financial_explanation.dart';
import 'financial_runtime_recommendation_selection_provider.dart';

final currentAssistantRecommendationExplanationProvider =
    FutureProvider<Result<FinancialExplanation?>>((ref) async {
      final result = await ref.watch(
        financialRuntimeRecommendationSelectionProvider.future,
      );

      return switch (result) {
        Success(:final value) => Success(value.explanation),
        Failure(:final failure) => Failure(failure),
      };
    });
