import 'package:flutter_test/flutter_test.dart';
import 'package:ophir/features/accounts/domain/entities/account.dart';
import 'package:ophir/features/accounts/domain/enums/account_type.dart';
import 'package:ophir/features/assistant/domain/entities/financial_decision_option_type.dart';
import 'package:ophir/features/assistant/domain/entities/financial_intelligence_diagnostics_read_model.dart';
import 'package:ophir/features/assistant/domain/entities/financial_intelligence_recommendation_diagnostics_snapshot.dart';
import 'package:ophir/features/assistant/domain/entities/financial_intelligence_recommendation_type.dart';
import 'package:ophir/features/assistant/domain/entities/financial_model_period.dart';
import 'package:ophir/features/assistant/domain/entities/financial_recommendation.dart';
import 'package:ophir/features/assistant/domain/entities/financial_recommendation_comparison_flag.dart';
import 'package:ophir/features/assistant/domain/entities/financial_recommendation_comparison_read_model.dart';
import 'package:ophir/features/assistant/domain/entities/financial_recommendation_conflict_level.dart';
import 'package:ophir/features/assistant/domain/services/financial_behavior_compatibility_orchestrator.dart';
import 'package:ophir/features/assistant/domain/services/financial_decision_options_service.dart';
import 'package:ophir/features/assistant/domain/services/financial_deviation_service.dart';
import 'package:ophir/features/assistant/domain/services/financial_facts_service.dart';
import 'package:ophir/features/assistant/domain/services/financial_intelligence_deviation_service.dart';
import 'package:ophir/features/assistant/domain/services/financial_intelligence_models_service.dart';
import 'package:ophir/features/assistant/domain/services/financial_intelligence_problem_detection_service.dart';
import 'package:ophir/features/assistant/domain/services/financial_intelligence_recommendation_diagnostics_service.dart';
import 'package:ophir/features/assistant/domain/services/financial_models_service.dart';
import 'package:ophir/features/assistant/domain/services/financial_problem_detection_service.dart';
import 'package:ophir/features/assistant/domain/services/financial_recommendation_comparison_service.dart';
import 'package:ophir/features/assistant/domain/services/financial_recommendation_service.dart';
import 'package:ophir/features/categories/domain/entities/category.dart';
import 'package:ophir/features/categories/domain/enums/category_analytics_group.dart';
import 'package:ophir/features/categories/domain/enums/category_stable_key.dart';
import 'package:ophir/features/categories/domain/enums/category_type.dart';
import 'package:ophir/features/categories/domain/enums/category_ui_group.dart';
import 'package:ophir/features/operations/domain/entities/operation.dart';
import 'package:ophir/features/operations/domain/enums/operation_recurrence.dart';
import 'package:ophir/features/operations/domain/enums/operation_type.dart';

void main() {
  group('Stage 7M fixture coverage', () {
    test(
      'approved product review matrix compares legacy and shadow output',
      () {
        for (final fixture in _stage7MFixtures()) {
          final result = _evaluate(fixture);

          expect(
            result.legacyRecommendation?.selectedOptionType,
            fixture.expectedLegacyType,
            reason: '${fixture.name}: legacy recommendation type',
          );
          expect(
            result.shadowTypes,
            fixture.expectedShadowTypes,
            reason: '${fixture.name}: shadow recommendation types',
          );
          expect(
            result.comparison.legacyRecommendationType,
            fixture.expectedLegacyType,
            reason: '${fixture.name}: comparison legacy type',
          );
          expect(
            result.comparison.shadowRecommendationTypes,
            fixture.expectedShadowTypes,
            reason: '${fixture.name}: comparison shadow types',
          );
          expect(
            result.comparison.conflictLevel,
            fixture.expectedConflictLevel,
            reason: '${fixture.name}: conflictLevel',
          );
          expect(
            result.comparison.hasPositiveSignals,
            fixture.expectedHasPositiveSignals,
            reason: '${fixture.name}: positive signal flag',
          );
          expect(
            result.comparison.hasContextWarnings,
            fixture.expectedHasContextWarnings,
            reason: '${fixture.name}: context warning flag',
          );
          expect(
            result.comparison.hasCoverageWarnings,
            fixture.expectedHasCoverageWarnings,
            reason: '${fixture.name}: coverage warning flag',
          );
          expect(
            result.comparison.flags,
            containsAll(fixture.expectedFlags),
            reason: '${fixture.name}: comparison flags',
          );
        }
      },
    );
  });
}

List<_Stage7MFixture> _stage7MFixtures() {
  return [
    _Stage7MFixture(
      name: 'high ordinary spending',
      ordinaryExpenses: [
        _expenseSpec(
          id: 'rent',
          amount: 350,
          stableKey: CategoryStableKey.expenseHousingRent,
          analyticsGroup: CategoryAnalyticsGroup.essentialExpenses,
        ),
        _expenseSpec(
          id: 'haircare',
          amount: 450,
          stableKey: CategoryStableKey.expensePersonalCareHaircare,
          analyticsGroup: CategoryAnalyticsGroup.flexibleExpenses,
        ),
      ],
      expectedLegacyType:
          FinancialDecisionOptionType.reduceDiscretionarySpending,
      expectedShadowTypes: const [
        FinancialIntelligenceRecommendationType.reviewOrdinarySpendingStructure,
        FinancialIntelligenceRecommendationType.reduceReducibleSpending,
      ],
      expectedConflictLevel: FinancialRecommendationConflictLevel.aligned,
      expectedFlags: const [FinancialRecommendationComparisonFlag.directMatch],
    ),
    _Stage7MFixture(
      name: 'high asset building',
      ordinaryExpenses: [
        _expenseSpec(
          id: 'groceries',
          amount: 100,
          stableKey: CategoryStableKey.expenseFoodGroceries,
          analyticsGroup: CategoryAnalyticsGroup.essentialExpenses,
        ),
      ],
      specialExpenses: [
        _expenseSpec(
          id: 'savings',
          amount: 800,
          stableKey: CategoryStableKey.expenseFinanceSavings,
          analyticsGroup: CategoryAnalyticsGroup.financeSavings,
        ),
      ],
      expectedLegacyType:
          FinancialDecisionOptionType.reduceDiscretionarySpending,
      expectedShadowTypes: const [
        FinancialIntelligenceRecommendationType.maintainAssetBuildingMomentum,
      ],
      expectedConflictLevel: FinancialRecommendationConflictLevel.divergent,
      expectedHasPositiveSignals: true,
      expectedFlags: const [
        FinancialRecommendationComparisonFlag.positiveSignalPresent,
        FinancialRecommendationComparisonFlag.divergentMatch,
      ],
    ),
    _Stage7MFixture(
      name: 'high debt reduction',
      ordinaryExpenses: [
        _expenseSpec(
          id: 'groceries',
          amount: 100,
          stableKey: CategoryStableKey.expenseFoodGroceries,
          analyticsGroup: CategoryAnalyticsGroup.essentialExpenses,
        ),
      ],
      specialExpenses: [
        _expenseSpec(
          id: 'debt',
          amount: 800,
          stableKey: CategoryStableKey.expenseFinanceDebtRepayment,
          analyticsGroup: CategoryAnalyticsGroup.financeSavings,
        ),
      ],
      expectedLegacyType:
          FinancialDecisionOptionType.reduceDiscretionarySpending,
      expectedShadowTypes: const [
        FinancialIntelligenceRecommendationType.maintainDebtReductionMomentum,
      ],
      expectedConflictLevel: FinancialRecommendationConflictLevel.divergent,
      expectedHasPositiveSignals: true,
      expectedFlags: const [
        FinancialRecommendationComparisonFlag.positiveSignalPresent,
        FinancialRecommendationComparisonFlag.divergentMatch,
      ],
    ),
    _Stage7MFixture(
      name: 'credit card payment',
      ordinaryExpenses: [
        _expenseSpec(
          id: 'groceries',
          amount: 100,
          stableKey: CategoryStableKey.expenseFoodGroceries,
          analyticsGroup: CategoryAnalyticsGroup.essentialExpenses,
        ),
      ],
      specialExpenses: [
        _expenseSpec(
          id: 'credit-card',
          amount: 800,
          stableKey: CategoryStableKey.expenseFinanceCreditCardPayment,
          analyticsGroup: CategoryAnalyticsGroup.financeSavings,
        ),
      ],
      expectedLegacyType:
          FinancialDecisionOptionType.reduceDiscretionarySpending,
      expectedShadowTypes: const [
        FinancialIntelligenceRecommendationType.maintainDebtReductionMomentum,
        FinancialIntelligenceRecommendationType.reviewTransactionContext,
      ],
      expectedConflictLevel: FinancialRecommendationConflictLevel.divergent,
      expectedHasPositiveSignals: true,
      expectedHasContextWarnings: true,
      expectedFlags: const [
        FinancialRecommendationComparisonFlag.positiveSignalPresent,
        FinancialRecommendationComparisonFlag.contextWarningPresent,
        FinancialRecommendationComparisonFlag.divergentMatch,
      ],
    ),
    _Stage7MFixture(
      name: 'cash withdrawal',
      ordinaryExpenses: [
        _expenseSpec(
          id: 'groceries',
          amount: 100,
          stableKey: CategoryStableKey.expenseFoodGroceries,
          analyticsGroup: CategoryAnalyticsGroup.essentialExpenses,
        ),
      ],
      specialExpenses: [
        _expenseSpec(
          id: 'cash-withdrawal',
          amount: 800,
          stableKey: CategoryStableKey.expenseOtherCashWithdrawal,
          analyticsGroup: CategoryAnalyticsGroup.flexibleExpenses,
        ),
      ],
      expectedLegacyType:
          FinancialDecisionOptionType.reduceDiscretionarySpending,
      expectedShadowTypes: const [
        FinancialIntelligenceRecommendationType.reviewTransactionContext,
      ],
      expectedConflictLevel: FinancialRecommendationConflictLevel.divergent,
      expectedHasContextWarnings: true,
      expectedFlags: const [
        FinancialRecommendationComparisonFlag.contextWarningPresent,
        FinancialRecommendationComparisonFlag.divergentMatch,
      ],
    ),
    _Stage7MFixture(
      name: 'adjustment',
      ordinaryExpenses: [
        _expenseSpec(
          id: 'groceries',
          amount: 100,
          stableKey: CategoryStableKey.expenseFoodGroceries,
          analyticsGroup: CategoryAnalyticsGroup.essentialExpenses,
        ),
      ],
      specialExpenses: [
        _expenseSpec(
          id: 'adjustment',
          amount: 800,
          stableKey: CategoryStableKey.expenseOtherAdjustment,
          analyticsGroup: CategoryAnalyticsGroup.flexibleExpenses,
        ),
      ],
      expectedLegacyType:
          FinancialDecisionOptionType.reduceDiscretionarySpending,
      expectedShadowTypes: const [
        FinancialIntelligenceRecommendationType.reviewTransactionContext,
      ],
      expectedConflictLevel: FinancialRecommendationConflictLevel.divergent,
      expectedHasContextWarnings: true,
      expectedFlags: const [
        FinancialRecommendationComparisonFlag.contextWarningPresent,
        FinancialRecommendationComparisonFlag.divergentMatch,
      ],
    ),
    _Stage7MFixture(
      name: 'broad unresolved category',
      ordinaryExpenses: [
        _expenseSpec(
          id: 'broad-legacy',
          amount: 900,
          stableKey: null,
          nameKey: 'categoryUtilities',
          analyticsGroup: CategoryAnalyticsGroup.flexibleExpenses,
        ),
      ],
      expectedLegacyType:
          FinancialDecisionOptionType.reduceDiscretionarySpending,
      expectedShadowTypes: const [
        FinancialIntelligenceRecommendationType.improveCategoryCoverage,
      ],
      expectedConflictLevel: FinancialRecommendationConflictLevel.divergent,
      expectedHasCoverageWarnings: true,
      expectedFlags: const [
        FinancialRecommendationComparisonFlag.coverageWarningPresent,
        FinancialRecommendationComparisonFlag.divergentMatch,
      ],
    ),
    _Stage7MFixture(
      name: 'mandatory spending pressure',
      ordinaryExpenses: [
        _expenseSpec(
          id: 'rent',
          amount: 650,
          stableKey: CategoryStableKey.expenseHousingRent,
          analyticsGroup: CategoryAnalyticsGroup.essentialExpenses,
        ),
      ],
      expectedLegacyType: null,
      expectedShadowTypes: const [
        FinancialIntelligenceRecommendationType.reviewMandatoryCosts,
      ],
      expectedConflictLevel: FinancialRecommendationConflictLevel.shadowOnly,
      expectedFlags: const [],
    ),
    _Stage7MFixture(
      name: 'discretionary spending pressure',
      ordinaryExpenses: [
        _expenseSpec(
          id: 'movies',
          amount: 250,
          stableKey: CategoryStableKey.expenseEntertainmentLifestyleMovies,
          analyticsGroup: CategoryAnalyticsGroup.lifestyleEntertainment,
        ),
      ],
      expectedLegacyType: null,
      expectedShadowTypes: const [
        FinancialIntelligenceRecommendationType
            .deferOrReduceDiscretionarySpending,
      ],
      expectedConflictLevel: FinancialRecommendationConflictLevel.shadowOnly,
      expectedFlags: const [],
    ),
    _Stage7MFixture(
      name: 'context-required-heavy month',
      ordinaryExpenses: [
        _expenseSpec(
          id: 'groceries',
          amount: 100,
          stableKey: CategoryStableKey.expenseFoodGroceries,
          analyticsGroup: CategoryAnalyticsGroup.essentialExpenses,
        ),
      ],
      specialExpenses: [
        _expenseSpec(
          id: 'credit-card',
          amount: 400,
          stableKey: CategoryStableKey.expenseFinanceCreditCardPayment,
          analyticsGroup: CategoryAnalyticsGroup.financeSavings,
        ),
        _expenseSpec(
          id: 'cash-withdrawal',
          amount: 300,
          stableKey: CategoryStableKey.expenseOtherCashWithdrawal,
          analyticsGroup: CategoryAnalyticsGroup.flexibleExpenses,
        ),
        _expenseSpec(
          id: 'adjustment',
          amount: 200,
          stableKey: CategoryStableKey.expenseOtherAdjustment,
          analyticsGroup: CategoryAnalyticsGroup.flexibleExpenses,
        ),
      ],
      expectedLegacyType:
          FinancialDecisionOptionType.reduceDiscretionarySpending,
      expectedShadowTypes: const [
        FinancialIntelligenceRecommendationType.maintainDebtReductionMomentum,
        FinancialIntelligenceRecommendationType.reviewTransactionContext,
      ],
      expectedConflictLevel: FinancialRecommendationConflictLevel.divergent,
      expectedHasPositiveSignals: true,
      expectedHasContextWarnings: true,
      expectedFlags: const [
        FinancialRecommendationComparisonFlag.positiveSignalPresent,
        FinancialRecommendationComparisonFlag.contextWarningPresent,
        FinancialRecommendationComparisonFlag.divergentMatch,
      ],
    ),
  ];
}

_Stage7MResult _evaluate(_Stage7MFixture fixture) {
  final categories = fixture.categories;
  final operations = fixture.operations;
  final legacyRecommendation = _legacyRecommendationFor(
    operations: operations,
    categories: categories,
  );
  final shadowDiagnostics = _shadowDiagnosticsFor(
    operations: operations,
    categories: categories,
  );
  final comparison = const FinancialRecommendationComparisonService().build(
    legacyRecommendation: legacyRecommendation,
    shadowDiagnostics: shadowDiagnostics,
  );

  return _Stage7MResult(
    legacyRecommendation: legacyRecommendation,
    shadowDiagnostics: shadowDiagnostics,
    comparison: comparison,
  );
}

FinancialRecommendation? _legacyRecommendationFor({
  required List<Operation> operations,
  required List<Category> categories,
}) {
  const factsService = FinancialFactsService();
  const modelsService = FinancialModelsService();
  const deviationService = FinancialDeviationService();
  const problemDetectionService = FinancialProblemDetectionService();
  const decisionOptionsService = FinancialDecisionOptionsService();

  final facts = factsService.buildSnapshot(
    accounts: [_account()],
    operations: operations,
    categories: categories,
  );
  final models = modelsService.calculateAll(
    snapshot: facts,
    period: _period,
    calculatedAt: _now,
  );
  final deviations = deviationService.detect(models);
  final problems = problemDetectionService.detect(deviations);
  final options = decisionOptionsService.generate(problems);

  return FinancialRecommendationService(generatedAt: _now).recommend(options);
}

FinancialIntelligenceRecommendationDiagnosticsSnapshot _shadowDiagnosticsFor({
  required List<Operation> operations,
  required List<Category> categories,
}) {
  const compatibility = FinancialBehaviorCompatibilityOrchestrator();
  const modelsService = FinancialIntelligenceModelsService();
  const deviationService = FinancialIntelligenceDeviationService();
  const problemDetectionService =
      FinancialIntelligenceProblemDetectionService();
  const diagnosticsService =
      FinancialIntelligenceRecommendationDiagnosticsService();

  final behaviorOutput = compatibility.build(
    operations: operations,
    categories: categories,
    period: _period,
  );
  final models = modelsService.build(
    output: behaviorOutput,
    period: _period,
    incomeTotal: _incomeAmount,
  );
  final diagnostics = FinancialIntelligenceDiagnosticsReadModel(
    period: _period,
    incomeDenominator: _incomeAmount,
    behaviorOutput: behaviorOutput,
    modelsSnapshot: models,
  );
  final deviations = deviationService.detect(diagnostics);
  final problems = problemDetectionService.detect(deviations);

  return diagnosticsService.build(problems);
}

_ExpenseSpec _expenseSpec({
  required String id,
  required double amount,
  required CategoryStableKey? stableKey,
  required CategoryAnalyticsGroup analyticsGroup,
  String nameKey = 'categoryUnknownLegacy',
}) {
  return _ExpenseSpec(
    id: id,
    amount: amount,
    stableKey: stableKey,
    analyticsGroup: analyticsGroup,
    nameKey: nameKey,
  );
}

Account _account() {
  return Account(
    id: _accountId,
    userId: _userId,
    name: 'Checking',
    type: AccountType.bank,
    currencyCode: _currency,
    initialBalance: 5000,
    iconKey: 'checking',
    colorKey: 'blue',
    sortOrder: 0,
    isArchived: false,
    createdAt: _now,
    updatedAt: _now,
  );
}

Category _incomeCategory() {
  return _category(
    id: _incomeCategoryId,
    type: CategoryType.income,
    stableKey: CategoryStableKey.incomeEmploymentSalary,
    analyticsGroup: CategoryAnalyticsGroup.income,
    nameKey: 'categorySalary',
  );
}

Category _category({
  required String id,
  required CategoryType type,
  required CategoryStableKey? stableKey,
  required CategoryAnalyticsGroup analyticsGroup,
  required String nameKey,
}) {
  return Category(
    id: id,
    type: type,
    uiGroup: type == CategoryType.income
        ? CategoryUiGroup.income
        : CategoryUiGroup.dailyLife,
    analyticsGroup: analyticsGroup,
    nameKey: nameKey,
    iconKey: 'other',
    colorKey: 'blue',
    sortOrder: 0,
    isActive: true,
    createdAt: _now,
    updatedAt: _now,
    exampleKey: 'categoryExampleDefault',
    stableKey: stableKey?.toJson(),
  );
}

Operation _incomeOperation() {
  return Operation(
    id: 'income',
    userId: _userId,
    toAccountId: _accountId,
    categoryId: _incomeCategoryId,
    type: OperationType.income,
    amount: _incomeAmount,
    currencyCode: _currency,
    occurredAt: _now,
    recurrence: OperationRecurrence.none,
    isRecurring: false,
    createdAt: _now,
    updatedAt: _now,
  );
}

Operation _expenseOperation(_ExpenseSpec spec) {
  return Operation(
    id: spec.id,
    userId: _userId,
    fromAccountId: _accountId,
    categoryId: spec.id,
    type: OperationType.expense,
    amount: spec.amount,
    currencyCode: _currency,
    occurredAt: _now,
    recurrence: OperationRecurrence.none,
    isRecurring: false,
    createdAt: _now,
    updatedAt: _now,
  );
}

final class _Stage7MFixture {
  const _Stage7MFixture({
    required this.name,
    required this.ordinaryExpenses,
    this.specialExpenses = const [],
    required this.expectedLegacyType,
    required this.expectedShadowTypes,
    required this.expectedConflictLevel,
    this.expectedHasPositiveSignals = false,
    this.expectedHasContextWarnings = false,
    this.expectedHasCoverageWarnings = false,
    required this.expectedFlags,
  });

  final String name;
  final List<_ExpenseSpec> ordinaryExpenses;
  final List<_ExpenseSpec> specialExpenses;
  final FinancialDecisionOptionType? expectedLegacyType;
  final List<FinancialIntelligenceRecommendationType> expectedShadowTypes;
  final FinancialRecommendationConflictLevel expectedConflictLevel;
  final bool expectedHasPositiveSignals;
  final bool expectedHasContextWarnings;
  final bool expectedHasCoverageWarnings;
  final List<FinancialRecommendationComparisonFlag> expectedFlags;

  List<_ExpenseSpec> get _expenses => [...ordinaryExpenses, ...specialExpenses];

  List<Category> get categories => [
    _incomeCategory(),
    for (final spec in _expenses)
      _category(
        id: spec.id,
        type: CategoryType.expense,
        stableKey: spec.stableKey,
        analyticsGroup: spec.analyticsGroup,
        nameKey: spec.nameKey,
      ),
  ];

  List<Operation> get operations => [
    _incomeOperation(),
    for (final spec in _expenses) _expenseOperation(spec),
  ];
}

final class _ExpenseSpec {
  const _ExpenseSpec({
    required this.id,
    required this.amount,
    required this.stableKey,
    required this.analyticsGroup,
    required this.nameKey,
  });

  final String id;
  final double amount;
  final CategoryStableKey? stableKey;
  final CategoryAnalyticsGroup analyticsGroup;
  final String nameKey;
}

final class _Stage7MResult {
  const _Stage7MResult({
    required this.legacyRecommendation,
    required this.shadowDiagnostics,
    required this.comparison,
  });

  final FinancialRecommendation? legacyRecommendation;
  final FinancialIntelligenceRecommendationDiagnosticsSnapshot
  shadowDiagnostics;
  final FinancialRecommendationComparisonReadModel comparison;

  List<FinancialIntelligenceRecommendationType> get shadowTypes {
    return shadowDiagnostics.recommendations
        .map((recommendation) => recommendation.type)
        .toList(growable: false);
  }
}

const _userId = 'stage-7m-user';
const _accountId = 'stage-7m-checking';
const _incomeCategoryId = 'salary';
const _currency = 'CAD';
const _incomeAmount = 1000.0;
final _now = DateTime.utc(2035, 6, 15);
final _period = FinancialModelPeriod(
  start: DateTime.utc(2035, 6),
  end: DateTime.utc(2035, 7),
);
