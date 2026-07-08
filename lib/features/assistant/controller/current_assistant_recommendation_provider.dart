import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/result.dart';
import '../domain/entities/financial_recommendation.dart';
import 'assistant_dashboard_briefing_provider.dart';

final currentAssistantRecommendationProvider =
    FutureProvider<Result<FinancialRecommendation?>>((ref) async {
      final result = await ref.watch(assistantDashboardBriefingProvider.future);

      return switch (result) {
        Success(:final value) => Success(value.recommendation),
        Failure(:final failure) => Failure(failure),
      };
    });
