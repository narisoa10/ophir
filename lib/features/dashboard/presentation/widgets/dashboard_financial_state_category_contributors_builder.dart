import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/errors/result.dart';
import '../../../../core/localization/generated/app_localizations.dart';
import '../../../../core/theme_v1/app_colors.dart';
import '../../../../core/theme_v1/app_dimensions.dart';
import '../../../../core/theme_v1/app_radius.dart';
import '../../../../core/theme_v1/app_spacing.dart';
import '../../../../core/theme_v1/app_typography.dart';
import '../../../assistant/controller/financial_state_category_contributors_provider.dart';
import '../../../assistant/domain/entities/financial_state_category_contributors_snapshot.dart';
import '../adapters/financial_state_category_contributors_presentation_adapter.dart';
import '../models/dashboard_financial_state_category_contributor_presentation.dart';
import '../models/dashboard_financial_state_category_contributors_presentation.dart';
import 'dashboard_panel.dart';

class DashboardFinancialStateCategoryContributorsBuilder
    extends ConsumerWidget {
  const DashboardFinancialStateCategoryContributorsBuilder({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(financialStateCategoryContributorsProvider);
    final l10n = AppLocalizations.of(context);

    if (state.isLoading) {
      return const DashboardPanel(
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (state.hasError) {
      return _FailurePanel(message: l10n.failureUnknown);
    }

    final snapshot = _snapshotFromResult(state.valueOrNull);
    if (snapshot == null) {
      return _FailurePanel(message: l10n.failureUnknown);
    }

    final presentation =
        const FinancialStateCategoryContributorsPresentationAdapter()
            .toPresentation(
              snapshot: snapshot,
              l10n: l10n,
              formatMoney: (amount, currencyCode) {
                return _formatMoney(context, amount, currencyCode);
              },
            );

    return _ContributorsCard(presentation: presentation);
  }

  FinancialStateCategoryContributorsSnapshot? _snapshotFromResult(
    Result<FinancialStateCategoryContributorsSnapshot>? result,
  ) {
    return switch (result) {
      Success<FinancialStateCategoryContributorsSnapshot>(:final value) =>
        value,
      Failure<FinancialStateCategoryContributorsSnapshot>() => null,
      null => null,
    };
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
}

class _ContributorsCard extends StatelessWidget {
  const _ContributorsCard({required this.presentation});

  final DashboardFinancialStateCategoryContributorsPresentation presentation;

  @override
  Widget build(BuildContext context) {
    return DashboardPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(presentation.title, style: AppTypography.sectionTitle),
          const SizedBox(height: AppSpacing.md),
          _AmountRow(
            label: presentation.requiredAmountLabel,
            amount: presentation.requiredAmount,
          ),
          const SizedBox(height: AppSpacing.sm),
          _AmountRow(
            label: presentation.coveredAmountLabel,
            amount: presentation.coveredAmount,
          ),
          if (presentation.contributors.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.md),
            for (final contributor in presentation.contributors) ...[
              _ContributorRow(contributor: contributor),
              if (contributor != presentation.contributors.last)
                const SizedBox(height: AppSpacing.md),
            ],
          ],
        ],
      ),
    );
  }
}

class _AmountRow extends StatelessWidget {
  const _AmountRow({required this.label, required this.amount});

  final String label;
  final String amount;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: AppTypography.caption,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        const SizedBox(width: AppSpacing.md),
        Text(
          amount,
          style: AppTypography.currencyStrong.copyWith(
            color: AppColors.textPrimary,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.end,
        ),
      ],
    );
  }
}

class _ContributorRow extends StatelessWidget {
  const _ContributorRow({required this.contributor});

  final DashboardFinancialStateCategoryContributorPresentation contributor;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox.square(
          dimension: AppDimensions.financialStateMetricIconBox,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: contributor.backgroundColor,
              borderRadius: AppRadius.smRadius,
            ),
            child: Icon(
              contributor.icon,
              color: contributor.color,
              size: AppDimensions.iconSm,
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                contributor.name,
                style: AppTypography.bodyStrong,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              _PercentLine(contributor: contributor),
            ],
          ),
        ),
        const SizedBox(width: AppSpacing.md),
        Flexible(
          child: Text(
            contributor.amount,
            style: AppTypography.currencyStrong.copyWith(
              color: AppColors.textPrimary,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.end,
          ),
        ),
      ],
    );
  }
}

class _PercentLine extends StatelessWidget {
  const _PercentLine({required this.contributor});

  final DashboardFinancialStateCategoryContributorPresentation contributor;

  @override
  Widget build(BuildContext context) {
    final values = [
      if (contributor.percentOfIncome != null) contributor.percentOfIncome!,
      if (contributor.percentOfExpenses != null) contributor.percentOfExpenses!,
    ];

    if (values.isEmpty) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.xs),
      child: Text(
        values.join(' / '),
        style: AppTypography.captionStrong.copyWith(
          color: AppColors.textSecondary,
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}

class _FailurePanel extends StatelessWidget {
  const _FailurePanel({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return DashboardPanel(child: Text(message, style: AppTypography.body));
  }
}
