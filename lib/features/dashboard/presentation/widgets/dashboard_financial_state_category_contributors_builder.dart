import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/errors/result.dart';
import '../../../../core/localization/generated/app_localizations.dart';
import '../../../../core/localization/l10n/dashboard_financial_state_l10n.dart';
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

class DashboardFinancialStateCategoryContributorsBuilder
    extends ConsumerWidget {
  const DashboardFinancialStateCategoryContributorsBuilder({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(financialStateCategoryContributorsProvider);
    final l10n = AppLocalizations.of(context);

    if (state.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (state.hasError) {
      return Text(l10n.failureUnknown, style: AppTypography.body);
    }

    final snapshot = _snapshotFromResult(state.valueOrNull);
    if (snapshot == null) {
      return Text(l10n.failureUnknown, style: AppTypography.body);
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

    return _ContributorsContent(presentation: presentation);
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

class _ContributorsContent extends StatelessWidget {
  const _ContributorsContent({required this.presentation});

  final DashboardFinancialStateCategoryContributorsPresentation presentation;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(presentation.title, style: AppTypography.sectionTitle),
        const SizedBox(height: AppSpacing.md),
        if (presentation.contributors.isEmpty)
          Text(l10n.dashboardContributorEmpty, style: AppTypography.body)
        else
          for (final contributor in presentation.contributors) ...[
            _ContributorRow(contributor: contributor),
            if (contributor != presentation.contributors.last)
              const SizedBox(height: AppSpacing.md),
          ],
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
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                contributor.roleLabel,
                style: AppTypography.caption.copyWith(
                  color: AppColors.textSecondary,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: AppSpacing.xs),
              _PercentLine(contributor: contributor),
            ],
          ),
        ),
        const SizedBox(width: AppSpacing.md),
        Flexible(
          fit: FlexFit.loose,
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
    final l10n = AppLocalizations.of(context);
    final percentOfIncome = contributor.percentOfIncome;

    if (percentOfIncome == null) {
      return const SizedBox.shrink();
    }

    return Text(
      l10n.dashboardContributorPercentOfIncome(percentOfIncome),
      style: AppTypography.captionStrong.copyWith(
        color: AppColors.textSecondary,
      ),
    );
  }
}
