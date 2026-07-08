import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/app_failure.dart';
import '../../../core/errors/result.dart';
import '../domain/entities/financial_intelligence_problems_snapshot.dart';
import '../domain/services/financial_intelligence_problem_detection_service.dart';
import 'financial_intelligence_deviations_provider.dart';

final financialIntelligenceProblemsProvider =
    FutureProvider<Result<FinancialIntelligenceProblemsSnapshot>>((ref) async {
      final deviationsResult = await ref.watch(
        financialIntelligenceDeviationsProvider.future,
      );
      final deviations = _value(deviationsResult);

      if (deviations == null) {
        return Failure(_failureOrUnknown(deviationsResult));
      }

      return Success(
        const FinancialIntelligenceProblemDetectionService().detect(deviations),
      );
    });

T? _value<T>(Result<T> result) {
  return switch (result) {
    Success<T>(:final value) => value,
    Failure<T>() => null,
  };
}

AppFailure _failureOrUnknown(Result<Object?> result) {
  return switch (result) {
    Failure<Object?>(:final failure) => failure,
    Success<Object?>() => const UnknownFailure(),
  };
}
