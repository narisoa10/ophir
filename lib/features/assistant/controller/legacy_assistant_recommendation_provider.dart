import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/result.dart';
import '../domain/entities/financial_recommendation.dart';
import 'legacy_assistant_dashboard_briefing_provider.dart';

final legacyAssistantRecommendationProvider =
    FutureProvider<Result<FinancialRecommendation?>>((ref) async {
      final result = await ref.watch(
        legacyAssistantDashboardBriefingProvider.future,
      );

      return switch (result) {
        Success(:final value) => Success(value.recommendation),
        Failure(:final failure) => Failure(failure),
      };
    });
