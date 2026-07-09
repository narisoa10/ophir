import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/app_failure.dart';
import '../../../core/errors/result.dart';
import '../domain/entities/assistant_dashboard_briefing.dart';
import '../domain/entities/financial_intelligence_diagnostics_read_model.dart';
import '../domain/entities/financial_intelligence_model_parity_snapshot.dart';
import '../domain/services/financial_intelligence_model_parity_service.dart';
import 'financial_intelligence_diagnostics_provider.dart';
import 'legacy_assistant_dashboard_briefing_provider.dart';

final financialIntelligenceModelParityProvider =
    FutureProvider<Result<FinancialIntelligenceModelParitySnapshot>>((
      ref,
    ) async {
      final legacyResult = await ref.watch(
        legacyAssistantDashboardBriefingProvider.future,
      );
      final diagnosticsResult = await ref.watch(
        financialIntelligenceDiagnosticsProvider.future,
      );
      final legacy = _value(legacyResult);
      final diagnostics = _value(diagnosticsResult);

      if (legacy == null || diagnostics == null) {
        return Failure(_failureOrUnknown(legacyResult, diagnosticsResult));
      }

      return Success(
        const FinancialIntelligenceModelParityService().compare(
          legacyModelResults: legacy.modelResults,
          intelligenceIncomeDenominator: diagnostics.incomeDenominator,
          intelligenceModels: diagnostics.modelsSnapshot,
        ),
      );
    });

T? _value<T>(Result<T> result) {
  return switch (result) {
    Success<T>(:final value) => value,
    Failure<T>() => null,
  };
}

AppFailure _failureOrUnknown(
  Result<AssistantDashboardBriefing> legacyResult,
  Result<FinancialIntelligenceDiagnosticsReadModel> diagnosticsResult,
) {
  return switch (legacyResult) {
    Failure<AssistantDashboardBriefing>(:final failure) => failure,
    _ => switch (diagnosticsResult) {
      Failure<FinancialIntelligenceDiagnosticsReadModel>(:final failure) =>
        failure,
      _ => const UnknownFailure(),
    },
  };
}
