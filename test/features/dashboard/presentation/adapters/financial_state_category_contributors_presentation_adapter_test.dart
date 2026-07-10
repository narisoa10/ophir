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
    test('deficit maps labels and money through injected formatter', () {
      final l10n = AppLocalizationsEn();
      final presentation = adapter.toPresentation(
        snapshot: _snapshot(
          stateType: FinancialStateType.deficit,
          requiredAmount: 125,
          coveredAmount: 80,
        ),
        l10n: l10n,
        formatMoney: _formatMoney,
      );

      expect(presentation.title, l10n.dashboardContributorDeficitTitle);
      expect(
        presentation.requiredAmountLabel,
        l10n.dashboardContributorRequiredAmountLabel,
      );
      expect(
        presentation.coveredAmountLabel,
        l10n.dashboardContributorCoveredAmountLabel,
      );
      expect(presentation.requiredAmount, '125.0 CAD');
      expect(presentation.coveredAmount, '80.0 CAD');
    });

    test('fragileBalance maps title from l10n', () {
      final l10n = AppLocalizationsFr();
      final presentation = adapter.toPresentation(
        snapshot: _snapshot(stateType: FinancialStateType.fragileBalance),
        l10n: l10n,
        formatMoney: _formatMoney,
      );

      expect(presentation.title, l10n.dashboardContributorFragileTitle);
    });

    test('stable maps title from l10n', () {
      final l10n = AppLocalizationsRu();
      final presentation = adapter.toPresentation(
        snapshot: _snapshot(stateType: FinancialStateType.stable),
        l10n: l10n,
        formatMoney: _formatMoney,
      );

      expect(presentation.title, l10n.dashboardContributorStableTitle);
    });

    test('growth maps title from l10n', () {
      final l10n = AppLocalizationsEn();
      final presentation = adapter.toPresentation(
        snapshot: _snapshot(stateType: FinancialStateType.growth),
        l10n: l10n,
        formatMoney: _formatMoney,
      );

      expect(presentation.title, l10n.dashboardContributorGrowthTitle);
    });

    test('strongPosition maps title from l10n', () {
      final l10n = AppLocalizationsEn();
      final presentation = adapter.toPresentation(
        snapshot: _snapshot(stateType: FinancialStateType.strongPosition),
        l10n: l10n,
        formatMoney: _formatMoney,
      );

      expect(presentation.title, l10n.dashboardContributorStrongPositionTitle);
    });

    test(
      'contributor mapping uses taxonomy presentation and formats values',
      () {
        final l10n = AppLocalizationsEn();
        const stableKey = CategoryStableKey.expenseHousingRent;
        final expectedCategory = const CategoryDefinitionAdapter()
            .toPresentation(CategoryTaxonomy.definitionFor(stableKey)!, l10n);

        final presentation = adapter.toPresentation(
          snapshot: _snapshot(
            contributors: const [
              FinancialStateCategoryContributor(
                categoryId: 'rent',
                stableKey: stableKey,
                amount: 720,
                percentOfIncome: 12.345,
                percentOfExpenses: 45.678,
                distributionRole:
                    CategoryFinancialDistributionRole.mandatoryExpenses,
                spendingPattern: SpendingPattern.usuallyRecurring,
              ),
            ],
          ),
          l10n: l10n,
          formatMoney: _formatMoney,
        );

        final contributor = presentation.contributors.single;
        expect(contributor.categoryId, 'rent');
        expect(contributor.name, expectedCategory.name);
        expect(contributor.icon, expectedCategory.icon);
        expect(contributor.color, expectedCategory.color);
        expect(contributor.backgroundColor, expectedCategory.backgroundColor);
        expect(contributor.amount, '720.0 CAD');
        expect(contributor.percentOfIncome, '12.3%');
        expect(contributor.percentOfExpenses, '45.7%');
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

    test('null currency uses fixed decimals and does not call formatter', () {
      var formatCalls = 0;

      final presentation = adapter.toPresentation(
        snapshot: _snapshot(
          currencyCode: null,
          requiredAmount: 12.3,
          coveredAmount: 4.5,
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

      expect(presentation.requiredAmount, '12.30');
      expect(presentation.coveredAmount, '4.50');
      expect(presentation.contributors.single.amount, '6.70');
      expect(formatCalls, 0);
    });

    test('keeps contributor order', () {
      final presentation = adapter.toPresentation(
        snapshot: _snapshot(
          contributors: const [
            FinancialStateCategoryContributor(
              categoryId: 'groceries',
              stableKey: CategoryStableKey.expenseFoodGroceries,
              amount: 100,
              percentOfIncome: null,
              percentOfExpenses: null,
              distributionRole:
                  CategoryFinancialDistributionRole.mandatoryExpenses,
              spendingPattern: SpendingPattern.usuallyVariable,
            ),
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

      expect(
        presentation.contributors.map((contributor) => contributor.categoryId),
        ['groceries', 'restaurant'],
      );
    });

    test('uses real localizations for supported locales', () {
      final localizations = <AppLocalizations>[
        AppLocalizationsEn(),
        AppLocalizationsFr(),
        AppLocalizationsRu(),
      ];

      for (final l10n in localizations) {
        final presentation = adapter.toPresentation(
          snapshot: _snapshot(stateType: FinancialStateType.deficit),
          l10n: l10n,
          formatMoney: _formatMoney,
        );

        expect(presentation.title, l10n.dashboardContributorDeficitTitle);
      }
    });
  });
}

FinancialStateCategoryContributorsSnapshot _snapshot({
  FinancialStateType stateType = FinancialStateType.deficit,
  String? currencyCode = 'CAD',
  double requiredAmount = 100,
  double coveredAmount = 50,
  List<FinancialStateCategoryContributor> contributors = const [],
}) {
  return FinancialStateCategoryContributorsSnapshot(
    stateType: stateType,
    strategy: _strategyFor(stateType),
    requiredAmount: requiredAmount,
    coveredAmount: coveredAmount,
    isCoverageComplete: coveredAmount >= requiredAmount,
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
