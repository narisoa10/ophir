import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ophir/core/errors/app_failure.dart';
import 'package:ophir/core/errors/result.dart';
import 'package:ophir/core/evaluation/evaluation_clock.dart';
import 'package:ophir/core/evaluation/financial_evaluation_context_provider.dart';
import 'package:ophir/core/localization/generated/app_localizations.dart';
import 'package:ophir/core/localization/generated/app_localizations_en.dart';
import 'package:ophir/core/localization/l10n/dashboard_financial_state_l10n.dart';
import 'package:ophir/features/assistant/controller/assistant_dashboard_briefing_provider.dart';
import 'package:ophir/features/assistant/controller/financial_state_category_contributors_provider.dart';
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
import 'package:ophir/features/dashboard/presentation/screens/dashboard_screen.dart';
import 'package:ophir/features/dashboard/presentation/widgets/dashboard_financial_plan_section_card.dart';
import 'package:ophir/features/dashboard/presentation/widgets/dashboard_financial_state_category_contributors_builder.dart';
import 'package:ophir/features/dashboard/presentation/widgets/dashboard_financial_state_detail_content.dart';
import 'package:ophir/features/dashboard/presentation/models/dashboard_presentation.dart';
import 'package:ophir/features/profile/controller/profile_providers.dart';
import 'package:ophir/features/profile/domain/entities/profile.dart';
import 'package:ophir/features/profile/domain/repositories/profile_repository.dart';

void main() {
  group('DashboardScreen', () {
    testWidgets('uses shared clock for header date and greeting', (
      tester,
    ) async {
      final fixedNow = DateTime(2030, 5, 10, 6, 30);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            evaluationClockProvider.overrideWithValue(
              EvaluationClock(fixedNow: fixedNow),
            ),
            profileRepositoryProvider.overrideWithValue(
              _FakeProfileRepository(profile: _profile()),
            ),
            assistantDashboardBriefingProvider.overrideWith(
              (ref) async => const Failure(UnknownFailure()),
            ),
          ],
          child: const MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: DashboardScreen(),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Fri, May 10'), findsOneWidget);
      expect(find.text('Good morning, Ada'), findsOneWidget);
    });

    test('does not create DateTime.now inside dashboard feature', () {
      final dashboardFiles = Directory('lib/features/dashboard')
          .listSync(recursive: true)
          .whereType<File>()
          .where((file) => file.path.endsWith('.dart'));

      for (final file in dashboardFiles) {
        expect(
          file.readAsStringSync(),
          isNot(contains('DateTime.now()')),
          reason: file.path,
        );
      }
    });
  });

  group('Financial State Details', () {
    testWidgets('shows exactly four expandable cards with first open', (
      tester,
    ) async {
      await _pumpDashboardWidget(
        tester,
        DashboardFinancialStateDetailContent(
          detail: _detail(),
          contributors: const Text('Contributor content'),
        ),
      );

      expect(find.byType(DashboardFinancialPlanSectionCard), findsNWidgets(4));
      expect(find.text('Contributor content'), findsOneWidget);
    });

    testWidgets('cards two through four remain placeholder sections', (
      tester,
    ) async {
      final l10n = AppLocalizationsEn();

      await _pumpDashboardWidget(
        tester,
        DashboardFinancialStateDetailContent(
          detail: _detail(),
          contributors: const Text('Contributor content'),
        ),
      );

      await tester.tap(find.text(l10n.dashboardFinancialPlanBestEffectTitle));
      await tester.pumpAndSettle();
      await tester.tap(
        find.text(l10n.dashboardFinancialPlanExpectedResultTitle),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text(l10n.dashboardFinancialPlanRecoveryPlanTitle));
      await tester.pumpAndSettle();

      expect(
        find.text(l10n.dashboardFinancialPlanBestEffectPlaceholder),
        findsOneWidget,
      );
      expect(
        find.text(l10n.dashboardFinancialPlanExpectedResultPlaceholder),
        findsOneWidget,
      );
      expect(
        find.text(l10n.dashboardFinancialPlanRecoveryPlanPlaceholder),
        findsOneWidget,
      );
    });

    testWidgets('card one shows explanatory contributor fields', (
      tester,
    ) async {
      final l10n = AppLocalizationsEn();
      const stableKey = CategoryStableKey.expenseHousingRent;
      final category = const CategoryDefinitionAdapter().toPresentation(
        CategoryTaxonomy.definitionFor(stableKey)!,
        l10n,
      );

      await _pumpDashboardWidget(
        tester,
        const DashboardFinancialStateCategoryContributorsBuilder(),
        contributorsResult: Success(
          _snapshot(
            contributors: const [
              FinancialStateCategoryContributor(
                categoryId: 'rent',
                stableKey: stableKey,
                amount: 720,
                percentOfIncome: 12.3,
                percentOfExpenses: 45.7,
                distributionRole:
                    CategoryFinancialDistributionRole.mandatoryExpenses,
                spendingPattern: SpendingPattern.usuallyRecurring,
              ),
            ],
          ),
        ),
      );
      await tester.pump();

      expect(find.text(category.name), findsOneWidget);
      expect(find.text('720.00 CAD'), findsOneWidget);
      expect(
        find.text(l10n.dashboardContributorPercentOfIncome('12.3%')),
        findsOneWidget,
      );
      expect(
        find.text(l10n.dashboardContributorRequiredAmountLabel),
        findsNothing,
      );
      expect(
        find.text(l10n.dashboardContributorCoveredAmountLabel),
        findsNothing,
      );
    });

    testWidgets('fragileBalance boundary still shows contributors', (
      tester,
    ) async {
      final l10n = AppLocalizationsEn();
      final category = const CategoryDefinitionAdapter().toPresentation(
        CategoryTaxonomy.definitionFor(
          CategoryStableKey.expenseFoodRestaurant,
        )!,
        l10n,
      );

      await _pumpDashboardWidget(
        tester,
        const DashboardFinancialStateCategoryContributorsBuilder(),
        contributorsResult: Success(
          _snapshot(
            stateType: FinancialStateType.fragileBalance,
            requiredAmount: 0,
            contributors: const [
              FinancialStateCategoryContributor(
                categoryId: 'restaurant',
                stableKey: CategoryStableKey.expenseFoodRestaurant,
                amount: 80,
                percentOfIncome: 8,
                percentOfExpenses: null,
                distributionRole: CategoryFinancialDistributionRole.wants,
                spendingPattern: SpendingPattern.usuallyVariable,
              ),
            ],
          ),
        ),
      );
      await tester.pump();

      expect(find.text(l10n.dashboardContributorFragileTitle), findsOneWidget);
      expect(find.text(category.name), findsOneWidget);
      expect(find.text('80.00 CAD'), findsOneWidget);
    });

    testWidgets('positive states show positive factors when present', (
      tester,
    ) async {
      final savings = const CategoryDefinitionAdapter().toPresentation(
        CategoryTaxonomy.definitionFor(
          CategoryStableKey.expenseFinanceSavings,
        )!,
        AppLocalizationsEn(),
      );

      for (final stateType in [
        FinancialStateType.stable,
        FinancialStateType.growth,
        FinancialStateType.strongPosition,
      ]) {
        await _pumpDashboardWidget(
          tester,
          const DashboardFinancialStateCategoryContributorsBuilder(),
          contributorsResult: Success(
            _snapshot(
              stateType: stateType,
              contributors: const [
                FinancialStateCategoryContributor(
                  categoryId: 'savings',
                  stableKey: CategoryStableKey.expenseFinanceSavings,
                  amount: 150,
                  percentOfIncome: 15,
                  percentOfExpenses: null,
                  distributionRole:
                      CategoryFinancialDistributionRole.assetBuilding,
                  spendingPattern: SpendingPattern.usuallyRecurring,
                ),
              ],
            ),
          ),
        );
        await tester.pump();

        expect(find.text(savings.name), findsOneWidget);
        expect(find.text('150.00 CAD'), findsOneWidget);
      }
    });

    testWidgets('keeps contributor order from presentation', (tester) async {
      final l10n = AppLocalizationsEn();
      final groceries = const CategoryDefinitionAdapter().toPresentation(
        CategoryTaxonomy.definitionFor(CategoryStableKey.expenseFoodGroceries)!,
        l10n,
      );
      final restaurant = const CategoryDefinitionAdapter().toPresentation(
        CategoryTaxonomy.definitionFor(
          CategoryStableKey.expenseFoodRestaurant,
        )!,
        l10n,
      );

      await _pumpDashboardWidget(
        tester,
        const DashboardFinancialStateCategoryContributorsBuilder(),
        contributorsResult: Success(
          _snapshot(
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
        ),
      );
      await tester.pump();

      expect(
        tester.getTopLeft(find.text(groceries.name)).dy,
        lessThan(tester.getTopLeft(find.text(restaurant.name)).dy),
      );
    });

    testWidgets('builder shows empty state', (tester) async {
      final l10n = AppLocalizationsEn();

      await _pumpDashboardWidget(
        tester,
        const DashboardFinancialStateCategoryContributorsBuilder(),
        contributorsResult: Success(_snapshot(contributors: const [])),
      );
      await tester.pump();
      expect(find.text(l10n.dashboardContributorEmpty), findsOneWidget);
    });

    testWidgets('builder shows loading state', (tester) async {
      await _pumpDashboardWidget(
        tester,
        const DashboardFinancialStateCategoryContributorsBuilder(),
        contributorsFuture:
            Completer<Result<FinancialStateCategoryContributorsSnapshot>>()
                .future,
      );
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('builder handles failure state', (tester) async {
      final l10n = AppLocalizationsEn();

      await _pumpDashboardWidget(
        tester,
        const DashboardFinancialStateCategoryContributorsBuilder(),
        contributorsResult:
            const Failure<FinancialStateCategoryContributorsSnapshot>(
              UnknownFailure(),
            ),
      );
      await tester.pump();
      expect(find.text(l10n.failureUnknown), findsOneWidget);
    });
  });
}

final class _FakeProfileRepository implements ProfileRepository {
  const _FakeProfileRepository({required this.profile});

  final Profile profile;

  @override
  Future<Result<Profile>> getCurrentProfile() async {
    return Success(profile);
  }

  @override
  Future<Result<Profile>> updateProfile(Profile profile) async {
    return Success(profile);
  }

  @override
  Stream<Result<Profile>> watchCurrentProfile() {
    return Stream.value(Success(profile));
  }
}

Profile _profile() {
  final now = DateTime.utc(2026);

  return Profile(
    id: 'profile',
    email: 'ada@example.com',
    fullName: 'Ada',
    locale: 'en',
    currencyCode: 'CAD',
    timezone: 'America/Toronto',
    onboardingCompleted: true,
    createdAt: now,
    updatedAt: now,
  );
}

Future<void> _pumpDashboardWidget(
  WidgetTester tester,
  Widget child, {
  Result<FinancialStateCategoryContributorsSnapshot>? contributorsResult,
  Future<Result<FinancialStateCategoryContributorsSnapshot>>?
  contributorsFuture,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        financialStateCategoryContributorsProvider.overrideWith(
          (ref) =>
              contributorsFuture ??
              Future.value(
                contributorsResult ??
                    Success(_snapshot(contributors: const [])),
              ),
        ),
      ],
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(body: child),
      ),
    ),
  );
}

DashboardFinancialStateDetailPresentation _detail() {
  return const DashboardFinancialStateDetailPresentation(
    title: 'Financial state',
    currentStateTitle: 'Current state',
    currentStateDescription: 'Current state description',
    whyTitle: 'Why',
    whyDescription: 'Why description',
    problemsTitle: 'Problems',
    problems: ['Problem'],
    influenceTitle: 'Influence',
    buckets: [],
    recommendationTitle: 'Recommendation',
    recommendationDescription: 'Recommendation description',
    evidenceTitle: 'Evidence',
    evidence: ['Evidence'],
  );
}

FinancialStateCategoryContributorsSnapshot _snapshot({
  FinancialStateType stateType = FinancialStateType.deficit,
  double requiredAmount = 100,
  List<FinancialStateCategoryContributor> contributors = const [],
}) {
  return FinancialStateCategoryContributorsSnapshot(
    stateType: stateType,
    strategy: _strategyFor(stateType),
    requiredAmount: requiredAmount,
    coveredAmount: 0,
    isCoverageComplete: false,
    currencyCode: 'CAD',
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
