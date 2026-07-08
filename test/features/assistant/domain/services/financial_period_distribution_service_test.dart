import 'package:flutter_test/flutter_test.dart';
import 'package:ophir/features/assistant/domain/services/financial_facts_service.dart';
import 'package:ophir/features/assistant/domain/services/financial_models_service.dart';
import 'package:ophir/features/categories/domain/entities/category.dart';
import 'package:ophir/features/categories/domain/enums/category_analytics_group.dart';
import 'package:ophir/features/categories/domain/enums/category_type.dart';
import 'package:ophir/features/categories/domain/enums/category_ui_group.dart';
import 'package:ophir/features/operations/domain/entities/operation.dart';
import 'package:ophir/features/operations/domain/enums/operation_recurrence.dart';
import 'package:ophir/features/operations/domain/enums/operation_type.dart';
import 'package:ophir/features/assistant/domain/entities/financial_model_confidence.dart';
import 'package:ophir/features/assistant/domain/entities/financial_model_evidence.dart';
import 'package:ophir/features/assistant/domain/entities/financial_model_limitation.dart';
import 'package:ophir/features/assistant/domain/entities/financial_model_metadata.dart';
import 'package:ophir/features/assistant/domain/entities/financial_model_period.dart';
import 'package:ophir/features/assistant/domain/entities/financial_model_result.dart';
import 'package:ophir/features/assistant/domain/entities/financial_model_status.dart';
import 'package:ophir/features/assistant/domain/entities/financial_model_type.dart';
import 'package:ophir/features/assistant/domain/entities/financial_model_unit.dart';
import 'package:ophir/features/assistant/domain/entities/financial_period_distribution_bucket.dart';
import 'package:ophir/features/assistant/domain/services/financial_period_distribution_service.dart';

void main() {
  const service = FinancialPeriodDistributionService();

  test('allocates mandatory, flexible, wants, and savings buckets', () {
    final distribution = service.build(_models());

    expect(
      _amount(
        distribution,
        FinancialPeriodDistributionBucket.mandatoryExpenses,
      ),
      50,
    );
    expect(
      _amount(distribution, FinancialPeriodDistributionBucket.flexibleExpenses),
      20,
    );
    expect(_amount(distribution, FinancialPeriodDistributionBucket.wants), 10);
    expect(
      _amount(distribution, FinancialPeriodDistributionBucket.savings),
      20,
    );
  });

  test('maps analytics groups to exact distribution buckets', () {
    final distribution = service.build(
      _models(
        income: 300,
        essential: 90,
        flexible: 60,
        lifestyle: 30,
        finance: 25,
        net: 120,
      ),
    );

    expect(
      _amount(
        distribution,
        FinancialPeriodDistributionBucket.mandatoryExpenses,
      ),
      90,
    );
    expect(
      _amount(distribution, FinancialPeriodDistributionBucket.flexibleExpenses),
      60,
    );
    expect(_amount(distribution, FinancialPeriodDistributionBucket.wants), 30);
    expect(
      _amount(distribution, FinancialPeriodDistributionBucket.savings),
      120,
    );
  });

  test('keeps lifestyle and flexible expenses in separate buckets', () {
    final distribution = service.build(
      _models(income: 200, essential: 0, flexible: 0, lifestyle: 80, net: 120),
    );

    expect(
      _amount(distribution, FinancialPeriodDistributionBucket.flexibleExpenses),
      0,
    );
    expect(_amount(distribution, FinancialPeriodDistributionBucket.wants), 80);
  });

  test('keeps essential expenses only in mandatory bucket', () {
    final distribution = service.build(
      _models(income: 200, essential: 100, flexible: 0, lifestyle: 0, net: 100),
    );

    expect(
      _amount(
        distribution,
        FinancialPeriodDistributionBucket.mandatoryExpenses,
      ),
      100,
    );
    expect(
      _amount(distribution, FinancialPeriodDistributionBucket.flexibleExpenses),
      0,
    );
    expect(_amount(distribution, FinancialPeriodDistributionBucket.wants), 0);
  });

  test('zero flexible bucket means no flexible analytics group total', () {
    final distribution = service.build(
      _models(income: 100, essential: 40, flexible: 0, lifestyle: 10, net: 50),
    );

    expect(
      _amount(distribution, FinancialPeriodDistributionBucket.flexibleExpenses),
      0,
    );
  });

  test('pipeline maps flexible category operation to flexible bucket', () {
    const factsService = FinancialFactsService();
    const modelsService = FinancialModelsService();
    final period = FinancialModelPeriod(
      start: DateTime(2025, 5),
      end: DateTime(2025, 6),
    );
    final snapshot = factsService.buildSnapshot(
      operations: [
        _operation(id: 'salary', type: OperationType.income, amount: 1000),
        _operation(
          id: 'transport',
          type: OperationType.expense,
          amount: 120,
          categoryId: 'transport',
        ),
        _operation(
          id: 'cinema',
          type: OperationType.expense,
          amount: 80,
          categoryId: 'cinema',
        ),
      ],
      categories: [
        _category(
          id: 'transport',
          analyticsGroup: CategoryAnalyticsGroup.flexibleExpenses,
        ),
        _category(
          id: 'cinema',
          analyticsGroup: CategoryAnalyticsGroup.lifestyleEntertainment,
        ),
      ],
    );
    final models = modelsService.calculateAll(
      snapshot: snapshot,
      period: period,
      calculatedAt: DateTime(2025, 5, 31),
    );

    final distribution = service.build(models);

    expect(
      _amount(distribution, FinancialPeriodDistributionBucket.flexibleExpenses),
      120,
    );
    expect(_amount(distribution, FinancialPeriodDistributionBucket.wants), 80);
    expect(
      _amount(
        distribution,
        FinancialPeriodDistributionBucket.mandatoryExpenses,
      ),
      0,
    );
    expect(
      _amount(distribution, FinancialPeriodDistributionBucket.savings),
      800,
    );
  });

  test('calculates percents from income total', () {
    final distribution = service.build(_models(income: 200, net: 40));

    expect(
      _percent(
        distribution,
        FinancialPeriodDistributionBucket.mandatoryExpenses,
      ),
      0.25,
    );
    expect(
      _percent(distribution, FinancialPeriodDistributionBucket.savings),
      0.20,
    );
  });

  test('preserves limitation when allocated buckets exceed income', () {
    final distribution = service.build(
      _models(income: 90, essential: 60, flexible: 30, lifestyle: 20, net: 10),
    );

    final savings = distribution.items.firstWhere(
      (item) => item.bucket == FinancialPeriodDistributionBucket.savings,
    );
    expect(savings.amount, 10);
    expect(
      savings.limitations,
      contains(FinancialModelLimitation.derivedNegativeAmount),
    );
    expect(
      distribution.limitations,
      contains(FinancialModelLimitation.derivedNegativeAmount),
    );
  });

  test('returns no confidence allocation when income is unavailable', () {
    final distribution = service.build([
      _model(
        FinancialModelType.incomeTotal,
        null,
        status: FinancialModelStatus.insufficientData,
      ),
      _model(FinancialModelType.expenseTotal, 0, currencyCode: 'CAD'),
      _groupTotals(),
      _model(FinancialModelType.netCashFlow, 0, currencyCode: 'CAD'),
    ]);

    expect(distribution.confidence, FinancialModelConfidence.none);
    expect(distribution.items.every((item) => item.percent == 0), isTrue);
  });
}

double _amount(dynamic distribution, FinancialPeriodDistributionBucket bucket) {
  return distribution.items.firstWhere((item) => item.bucket == bucket).amount;
}

double _percent(
  dynamic distribution,
  FinancialPeriodDistributionBucket bucket,
) {
  return distribution.items.firstWhere((item) => item.bucket == bucket).percent;
}

List<FinancialModelResult> _models({
  double income = 100,
  double essential = 50,
  double flexible = 20,
  double lifestyle = 10,
  double finance = 0,
  double net = 20,
}) {
  return [
    _model(FinancialModelType.incomeTotal, income, currencyCode: 'CAD'),
    _model(
      FinancialModelType.expenseTotal,
      essential + flexible + lifestyle + finance,
      currencyCode: 'CAD',
    ),
    _groupTotals(
      essential: essential,
      flexible: flexible,
      lifestyle: lifestyle,
      finance: finance,
    ),
    _model(FinancialModelType.netCashFlow, net, currencyCode: 'CAD'),
  ];
}

FinancialModelResult _groupTotals({
  double essential = 50,
  double flexible = 20,
  double lifestyle = 10,
  double finance = 0,
}) {
  return _model(
    FinancialModelType.expenseAnalyticsGroupTotals,
    essential + flexible + lifestyle + finance,
    currencyCode: 'CAD',
    breakdown: [
      _model(
        FinancialModelType.expenseAnalyticsGroupTotals,
        essential,
        currencyCode: 'CAD',
        assumptions: const ['analyticsGroup:essentialExpenses'],
      ),
      _model(
        FinancialModelType.expenseAnalyticsGroupTotals,
        flexible,
        currencyCode: 'CAD',
        assumptions: const ['analyticsGroup:flexibleExpenses'],
      ),
      _model(
        FinancialModelType.expenseAnalyticsGroupTotals,
        lifestyle,
        currencyCode: 'CAD',
        assumptions: const ['analyticsGroup:lifestyleEntertainment'],
      ),
      _model(
        FinancialModelType.expenseAnalyticsGroupTotals,
        finance,
        currencyCode: 'CAD',
        assumptions: const ['analyticsGroup:financeSavings'],
      ),
    ],
  );
}

FinancialModelResult _model(
  FinancialModelType type,
  double? value, {
  String? currencyCode,
  FinancialModelStatus status = FinancialModelStatus.calculated,
  List<String> assumptions = const [],
  List<FinancialModelResult> breakdown = const [],
}) {
  final period = FinancialModelPeriod(
    start: DateTime(2025, 5),
    end: DateTime(2025, 6),
  );
  return FinancialModelResult(
    modelId: '${type.name}:${assumptions.join(',')}',
    modelType: type,
    status: status,
    value: value,
    unit: FinancialModelUnit.none,
    period: period,
    currencyCode: currencyCode,
    dataConfidence: FinancialModelConfidence.high,
    modelConfidence: FinancialModelConfidence.high,
    evidence: const FinancialModelEvidence(factIds: [], dataGapSourceIds: []),
    assumptions: assumptions,
    limitations: const [],
    inputCoverage: 1,
    metadata: FinancialModelMetadata(
      calculatedAt: DateTime(2025, 5),
      engineVersion: 'test',
      snapshotVersion: 'test',
    ),
    breakdown: breakdown,
  );
}

Operation _operation({
  required String id,
  required OperationType type,
  required double amount,
  String? categoryId,
}) {
  final now = DateTime(2025, 5, 15);

  return Operation(
    id: id,
    userId: 'user',
    type: type,
    amount: amount,
    currencyCode: 'CAD',
    occurredAt: now,
    recurrence: OperationRecurrence.none,
    isRecurring: false,
    createdAt: now,
    updatedAt: now,
    categoryId: categoryId,
  );
}

Category _category({
  required String id,
  required CategoryAnalyticsGroup analyticsGroup,
}) {
  final now = DateTime(2025, 5, 15);

  return Category(
    id: id,
    type: CategoryType.expense,
    uiGroup: CategoryUiGroup.dailyLife,
    analyticsGroup: analyticsGroup,
    nameKey: 'category.$id.name',
    iconKey: 'category.$id.icon',
    colorKey: 'category.$id.color',
    sortOrder: 0,
    isActive: true,
    createdAt: now,
    updatedAt: now,
    exampleKey: 'category.$id.example',
  );
}
