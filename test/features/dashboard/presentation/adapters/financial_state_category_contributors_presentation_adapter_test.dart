import 'package:flutter_test/flutter_test.dart';
import 'package:ophir/core/localization/generated/app_localizations.dart';
import 'package:ophir/core/localization/generated/app_localizations_en.dart';
import 'package:ophir/core/localization/generated/app_localizations_fr.dart';
import 'package:ophir/core/localization/generated/app_localizations_ru.dart';
import 'package:ophir/core/localization/l10n/dashboard_financial_state_l10n.dart';
import 'package:ophir/features/assistant/domain/entities/financial_model_limitation.dart';
import 'package:ophir/features/assistant/domain/entities/financial_state_category_contributor.dart';
import 'package:ophir/features/assistant/domain/entities/financial_state_category_contributors_snapshot.dart';
import 'package:ophir/features/assistant/domain/entities/financial_state_confidence.dart';
import 'package:ophir/features/assistant/domain/entities/financial_state_contributor_strategy.dart';
import 'package:ophir/features/assistant/domain/entities/financial_state_type.dart';
import 'package:ophir/features/categories/domain/entities/category_taxonomy.dart';
import 'package:ophir/features/categories/domain/enums/category_financial_distribution_role.dart';
import 'package:ophir/features/categories/domain/enums/category_stable_key.dart';
import 'package:ophir/features/categories/domain/enums/spending_pattern.dart';
import 'package:ophir/features/categories/presentation/adapters/category_definition_adapter.dart';
import 'package:ophir/features/dashboard/presentation/adapters/financial_state_category_contributors_presentation_adapter.dart';

void main() {
  const adapter = FinancialStateCategoryContributorsPresentationAdapter();

  group('FinancialStateCategoryContributorsPresentationAdapter', () {
    test('maps state titles from l10n', () {
      final cases = [
        _TitleCase(
          stateType: FinancialStateType.deficit,
          l10n: AppLocalizationsEn(),
          expectedTitle: (l10n) => l10n.dashboardContributorDeficitTitle,
        ),
        _TitleCase(
          stateType: FinancialStateType.fragileBalance,
          l10n: AppLocalizationsFr(),
          expectedTitle: (l10n) => l10n.dashboardContributorFragileTitle,
        ),
        _TitleCase(
          stateType: FinancialStateType.stable,
          l10n: AppLocalizationsRu(),
          expectedTitle: (l10n) => l10n.dashboardContributorStableTitle,
        ),
        _TitleCase(
          stateType: FinancialStateType.growth,
          l10n: AppLocalizationsEn(),
          expectedTitle: (l10n) => l10n.dashboardContributorGrowthTitle,
        ),
        _TitleCase(
          stateType: FinancialStateType.strongPosition,
          l10n: AppLocalizationsEn(),
          expectedTitle: (l10n) => l10n.dashboardContributorStrongPositionTitle,
        ),
      ];

      for (final testCase in cases) {
        final presentation = adapter.toPresentation(
          snapshot: _snapshot(stateType: testCase.stateType),
          l10n: testCase.l10n,
          formatMoney: _formatMoney,
        );

        expect(
          presentation.title,
          testCase.expectedTitle(testCase.l10n),
          reason: testCase.stateType.name,
        );
      }
    });

    test(
      'maps all contributors preserving domain order and explanatory fields',
      () {
        final l10n = AppLocalizationsEn();
        const rentKey = CategoryStableKey.expenseHousingRent;
        final expectedRent = const CategoryDefinitionAdapter().toPresentation(
          CategoryTaxonomy.definitionFor(rentKey)!,
          l10n,
        );

        final presentation = adapter.toPresentation(
          snapshot: _snapshot(
            contributors: const [
              FinancialStateCategoryContributor(
                categoryId: 'rent',
                stableKey: rentKey,
                amount: 720,
                percentOfIncome: 12.345,
                percentOfExpenses: 45.678,
                distributionRole:
                    CategoryFinancialDistributionRole.mandatoryExpenses,
                spendingPattern: SpendingPattern.usuallyRecurring,
              ),
              FinancialStateCategoryContributor(
                categoryId: 'restaurant',
                stableKey: CategoryStableKey.expenseFoodRestaurant,
                amount: 50,
                percentOfIncome: 1.2,
                percentOfExpenses: 3.4,
                distributionRole: CategoryFinancialDistributionRole.wants,
                spendingPattern: SpendingPattern.usuallyVariable,
              ),
            ],
          ),
          l10n: l10n,
          formatMoney: _formatMoney,
        );

        expect(
          presentation.contributors.map(
            (contributor) => contributor.categoryId,
          ),
          ['rent', 'restaurant'],
        );

        final rent = presentation.contributors.first;
        expect(rent.name, expectedRent.name);
        expect(rent.icon, expectedRent.icon);
        expect(rent.color, expectedRent.color);
        expect(rent.backgroundColor, expectedRent.backgroundColor);
        expect(rent.amount, '720.0 CAD');
        expect(rent.percentOfIncome, '12.3%');
        expect(rent.percentOfExpenses, '45.7%');
        expect(
          rent.distributionRole,
          CategoryFinancialDistributionRole.mandatoryExpenses,
        );
        expect(rent.spendingPattern, SpendingPattern.usuallyRecurring);
      },
    );

    test('nullable percentages stay null', () {
      final presentation = adapter.toPresentation(
        snapshot: _snapshot(
          contributors: const [
            FinancialStateCategoryContributor(
              categoryId: 'restaurant',
              stableKey: CategoryStableKey.expenseFoodRestaurant,
              amount: 50,
              percentOfIncome: null,
              percentOfExpenses: null,
              distributionRole: CategoryFinancialDistributionRole.wants,
              spendingPattern: SpendingPattern.usuallyVariable,
            ),
          ],
        ),
        l10n: AppLocalizationsEn(),
        formatMoney: _formatMoney,
      );

      expect(presentation.contributors.single.percentOfIncome, isNull);
      expect(presentation.contributors.single.percentOfExpenses, isNull);
    });

    test(
      'null currency formats contributor amount without money formatter',
      () {
        var formatCalls = 0;

        final presentation = adapter.toPresentation(
          snapshot: _snapshot(
            currencyCode: null,
            contributors: const [
              FinancialStateCategoryContributor(
                categoryId: 'restaurant',
                stableKey: CategoryStableKey.expenseFoodRestaurant,
                amount: 6.7,
                percentOfIncome: null,
                percentOfExpenses: null,
                distributionRole: CategoryFinancialDistributionRole.wants,
                spendingPattern: SpendingPattern.usuallyVariable,
              ),
            ],
          ),
          l10n: AppLocalizationsEn(),
          formatMoney: (amount, currencyCode) {
            formatCalls += 1;
            return _formatMoney(amount, currencyCode);
          },
        );

        expect(presentation.contributors.single.amount, '6.70');
        expect(formatCalls, 0);
      },
    );

    test('supports empty contributor list', () {
      final presentation = adapter.toPresentation(
        snapshot: _snapshot(contributors: const []),
        l10n: AppLocalizationsEn(),
        formatMoney: _formatMoney,
      );

      expect(presentation.contributors, isEmpty);
    });
  });
}

final class _TitleCase {
  const _TitleCase({
    required this.stateType,
    required this.l10n,
    required this.expectedTitle,
  });

  final FinancialStateType stateType;
  final AppLocalizations l10n;
  final String Function(AppLocalizations l10n) expectedTitle;
}

FinancialStateCategoryContributorsSnapshot _snapshot({
  FinancialStateType stateType = FinancialStateType.deficit,
  String? currencyCode = 'CAD',
  List<FinancialStateCategoryContributor> contributors = const [],
}) {
  return FinancialStateCategoryContributorsSnapshot(
    stateType: stateType,
    strategy: _strategyFor(stateType),
    requiredAmount: 100,
    coveredAmount: 50,
    isCoverageComplete: false,
    currencyCode: currencyCode,
    confidence: FinancialStateConfidence.high,
    contributors: contributors,
    limitations: const <FinancialModelLimitation>[],
  );
}

FinancialStateContributorStrategy _strategyFor(FinancialStateType stateType) {
  return switch (stateType) {
    FinancialStateType.deficit =>
      FinancialStateContributorStrategy.closeDeficit,
    FinancialStateType.fragileBalance =>
      FinancialStateContributorStrategy.buildSafetyMargin,
    FinancialStateType.stable =>
      FinancialStateContributorStrategy.preserveStability,
    FinancialStateType.growth =>
      FinancialStateContributorStrategy.supportGrowth,
    FinancialStateType.strongPosition =>
      FinancialStateContributorStrategy.protectStrongPosition,
  };
}

String _formatMoney(double amount, String currencyCode) {
  return '${amount.toStringAsFixed(1)} $currencyCode';
}
