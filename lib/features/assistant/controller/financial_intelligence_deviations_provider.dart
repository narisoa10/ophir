import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/app_failure.dart';
import '../../../core/errors/result.dart';
import '../domain/entities/financial_intelligence_deviations_snapshot.dart';
import '../domain/services/financial_intelligence_deviation_service.dart';
import 'financial_intelligence_diagnostics_provider.dart';

final financialIntelligenceDeviationsProvider =
    FutureProvider<Result<FinancialIntelligenceDeviationsSnapshot>>((ref) async {
      final diagnosticsResult = await ref.watch(
        financialIntelligenceDiagnosticsProvider.future,
      );
      final diagnostics = _value(diagnosticsResult);

      if (diagnostics == null) {
        return Failure(_failureOrUnknown(diagnosticsResult));
      }

      return Success(
        const FinancialIntelligenceDeviationService().detect(diagnostics),
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
