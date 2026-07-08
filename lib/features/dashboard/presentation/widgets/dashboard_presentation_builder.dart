import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/errors/result.dart';
import '../../../../core/evaluation/financial_evaluation_context_provider.dart';
import '../../../../core/localization/generated/app_localizations.dart';
import '../../../../core/theme_v1/app_typography.dart';
import '../../../assistant/controller/assistant_dashboard_briefing_provider.dart';
import '../../../assistant/domain/entities/assistant_dashboard_briefing.dart';
import '../adapters/dashboard_presentation_adapter.dart';
import '../models/dashboard_presentation.dart';
import 'dashboard_panel.dart';

class DashboardPresentationBuilder extends ConsumerWidget {
  const DashboardPresentationBuilder({required this.builder, super.key});

  final Widget Function(
    BuildContext context,
    DashboardPresentation presentation,
    AppLocalizations l10n,
  )
  builder;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final briefingState = ref.watch(assistantDashboardBriefingProvider);
    final evaluationContext = ref.watch(financialEvaluationContextProvider);
    final l10n = AppLocalizations.of(context);

    if (briefingState.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (briefingState.hasError) {
      return DashboardPanel(
        child: Text(l10n.failureUnknown, style: AppTypography.body),
      );
    }

    final briefing = _briefingFromResult(briefingState.valueOrNull);

    if (briefing == null) {
      return DashboardPanel(
        child: Text(l10n.failureUnknown, style: AppTypography.body),
      );
    }

    final presentation = const DashboardPresentationAdapter().toPresentation(
      briefing: briefing,
      l10n: l10n,
      now: evaluationContext.now,
      formatDate: (date) {
        return MaterialLocalizations.of(context).formatMediumDate(date);
      },
      formatMoney: (amount, currencyCode) {
        return _formatMoney(context, amount, currencyCode);
      },
    );

    return builder(context, presentation, l10n);
  }

  String _formatMoney(
    BuildContext context,
    double amount,
    String currencyCode,
  ) {
    final localizations = MaterialLocalizations.of(context);
    final sign = amount < 0 ? '-' : '';
    final absolute = amount.abs();
    var units = absolute.truncate();
    var cents = ((absolute - units) * 100).round();

    if (cents == 100) {
      units += 1;
      cents = 0;
    }

    final decimalSeparator = switch (AppLocalizations.of(context).localeName) {
      'fr' || 'ru' => ',',
      _ => '.',
    };
    final centsText = cents.toString().padLeft(2, '0');

    return '$sign${localizations.formatDecimal(units)}'
        '$decimalSeparator$centsText $currencyCode';
  }

  AssistantDashboardBriefing? _briefingFromResult(
    Result<AssistantDashboardBriefing>? result,
  ) {
    return switch (result) {
      Success<AssistantDashboardBriefing>(:final value) => value,
      Failure<AssistantDashboardBriefing>() => null,
      null => null,
    };
  }
}
