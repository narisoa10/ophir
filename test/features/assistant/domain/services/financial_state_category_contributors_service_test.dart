import 'package:flutter_test/flutter_test.dart';
import 'package:ophir/features/assistant/domain/entities/financial_behavior_fact.dart';
import 'package:ophir/features/assistant/domain/entities/financial_behavior_fact_kind.dart';
import 'package:ophir/features/assistant/domain/entities/financial_behavior_facts_snapshot.dart';
import 'package:ophir/features/assistant/domain/entities/financial_deviation.dart';
import 'package:ophir/features/assistant/domain/entities/financial_deviation_confidence.dart';
import 'package:ophir/features/assistant/domain/entities/financial_deviation_evidence.dart';
import 'package:ophir/features/assistant/domain/entities/financial_deviation_expected_value.dart';
import 'package:ophir/features/assistant/domain/entities/financial_deviation_metadata.dart';
import 'package:ophir/features/assistant/domain/entities/financial_deviation_severity.dart';
import 'package:ophir/features/assistant/domain/entities/financial_deviation_status.dart';
import 'package:ophir/features/assistant/domain/entities/financial_deviation_type.dart';
import 'package:ophir/features/assistant/domain/entities/financial_fact.dart';
import 'package:ophir/features/assistant/domain/entities/financial_fact_confidence.dart';
import 'package:ophir/features/assistant/domain/entities/financial_fact_source.dart';
import 'package:ophir/features/assistant/domain/entities/financial_fact_type.dart';
import 'package:ophir/features/assistant/domain/entities/financial_facts_snapshot.dart';
import 'package:ophir/features/assistant/domain/entities/financial_model_limitation.dart';
import 'package:ophir/features/assistant/domain/entities/financial_model_period.dart';
import 'package:ophir/features/assistant/domain/entities/financial_model_unit.dart';
import 'package:ophir/features/assistant/domain/entities/financial_problem.dart';
import 'package:ophir/features/assistant/domain/entities/financial_problem_confidence.dart';
import 'package:ophir/features/assistant/domain/entities/financial_problem_evidence.dart';
import 'package:ophir/features/assistant/domain/entities/financial_problem_impact.dart';
import 'package:ophir/features/assistant/domain/entities/financial_problem_metadata.dart';
import 'package:ophir/features/assistant/domain/entities/financial_problem_severity.dart';
import 'package:ophir/features/assistant/domain/entities/financial_problem_status.dart';
import 'package:ophir/features/assistant/domain/entities/financial_problem_type.dart';
import 'package:ophir/features/assistant/domain/entities/financial_state.dart';
import 'package:ophir/features/assistant/domain/entities/financial_state_category_contributors_snapshot.dart';
import 'package:ophir/features/assistant/domain/entities/financial_state_confidence.dart';
import 'package:ophir/features/assistant/domain/entities/financial_state_contributor_strategy.dart';
import 'package:ophir/features/assistant/domain/entities/financial_state_type.dart';
import 'package:ophir/features/assistant/domain/services/financial_state_category_contributors_service.dart';
import 'package:ophir/features/categories/domain/enums/category_financial_distribution_role.dart';
import 'package:ophir/features/categories/domain/enums/category_stable_key.dart';
import 'package:ophir/features/operations/domain/enums/operation_type.dart';

void main() {
  group('FinancialStateCategoryContributorsService', () {
    test(
      'deficit uses closeDeficit and required amount equals negative net',
      () {
        final snapshot = _build(
          financialState: _state(type: FinancialStateType.deficit, net: -125),
          behaviorFacts: _snapshot(),
        );

        expect(
          snapshot.strategy,
          FinancialStateContributorStrategy.closeDeficit,
        );
        expect(snapshot.requiredAmount, 125);
      },
    );

    test('fragileBalance uses buildSafetyMargin and required margin gap', () {
      final snapshot = _build(
        financialState: _state(
          type: FinancialStateType.fragileBalance,
          income: 1000,
          net: 40,
        ),
        behaviorFacts: _snapshot(),
      );

      expect(
        snapshot.strategy,
        FinancialStateContributorStrategy.buildSafetyMargin,
      );
      expect(snapshot.requiredAmount, 60);
    });

    test('stable has no required amount and complete empty coverage', () {
      final snapshot = _build(
        financialState: _state(type: FinancialStateType.stable),
        behaviorFacts: _snapshot(facts: [_fact(amount: 100)]),
      );

      expect(
        snapshot.strategy,
        FinancialStateContributorStrategy.preserveStability,
      );
      expect(snapshot.requiredAmount, 0);
      expect(snapshot.contributors, isEmpty);
      expect(snapshot.isCoverageComplete, isTrue);
    });

    test('growth uses supportGrowth', () {
      final snapshot = _build(
        financialState: _state(type: FinancialStateType.growth),
        behaviorFacts: _snapshot(),
      );

      expect(
        snapshot.strategy,
        FinancialStateContributorStrategy.supportGrowth,
      );
    });

    test('strongPosition uses protectStrongPosition', () {
      final snapshot = _build(
        financialState: _state(type: FinancialStateType.strongPosition),
        behaviorFacts: _snapshot(),
      );

      expect(
        snapshot.strategy,
        FinancialStateContributorStrategy.protectStrongPosition,
      );
    });

    test('fragileBalance at ten percent keeps explanatory contributors', () {
      final snapshot = _build(
        financialState: _state(
          type: FinancialStateType.fragileBalance,
          income: 1000,
          net: 100,
        ),
        behaviorFacts: _snapshot(
          facts: [_fact(categoryId: 'restaurant', amount: 120)],
        ),
        evidenceCategoryIds: {'restaurant'},
      );

      expect(snapshot.requiredAmount, 0);
      expect(snapshot.contributors, isNotEmpty);
      expect(
        snapshot.contributors.map((contributor) => contributor.categoryId),
        ['restaurant'],
      );
    });

    test('stable includes relevant positive contributors', () {
      final snapshot = _build(
        financialState: _state(type: FinancialStateType.stable),
        behaviorFacts: _snapshot(facts: [_positiveFact()]),
      );

      expect(snapshot.contributors, isNotEmpty);
    });

    test('growth includes relevant positive contributors', () {
      final snapshot = _build(
        financialState: _state(type: FinancialStateType.growth),
        behaviorFacts: _snapshot(facts: [_positiveFact()]),
      );

      expect(snapshot.contributors, isNotEmpty);
    });

    test('strongPosition includes relevant positive contributors', () {
      final snapshot = _build(
        financialState: _state(type: FinancialStateType.strongPosition),
        behaviorFacts: _snapshot(facts: [_positiveFact()]),
      );

      expect(snapshot.contributors, isNotEmpty);
    });

    test('prioritizes role before amount for diagnostic contributors', () {
      final snapshot = _build(
        financialState: _state(type: FinancialStateType.deficit, net: -1200),
        behaviorFacts: _snapshot(
          facts: [
            _fact(categoryId: 'wants-small', amount: 100),
            _fact(categoryId: 'wants-large', amount: 200),
            _fact(
              categoryId: 'mandatory',
              stableKey: CategoryStableKey.expenseHousingRent,
              amount: 1000,
              distributionRole:
                  CategoryFinancialDistributionRole.mandatoryExpenses,
            ),
            _fact(
              categoryId: 'flexible-small',
              amount: 30,
              distributionRole:
                  CategoryFinancialDistributionRole.flexibleExpenses,
            ),
            _fact(
              categoryId: 'flexible-large',
              amount: 900,
              distributionRole:
                  CategoryFinancialDistributionRole.flexibleExpenses,
            ),
          ],
        ),
      );

      expect(
        snapshot.contributors.map((contributor) => contributor.categoryId),
        [
          'wants-large',
          'wants-small',
          'flexible-large',
          'flexible-small',
          'mandatory',
        ],
      );
      expect(snapshot.contributors.map((contributor) => contributor.amount), [
        200,
        100,
        900,
        30,
        1000,
      ]);
    });

    test(
      'deficit includes only category confirmed by primary problem evidence',
      () {
        final snapshot = _build(
          financialState: _state(type: FinancialStateType.deficit, net: -100),
          behaviorFacts: _snapshot(
            facts: [
              _fact(categoryId: 'evidenced', amount: 40),
              _fact(categoryId: 'not-evidenced', amount: 300),
            ],
          ),
          evidenceCategoryIds: {'evidenced'},
        );

        expect(
          snapshot.contributors.map((contributor) => contributor.categoryId),
          ['evidenced'],
        );
      },
    );

    test('large mandatory category without evidence is not included', () {
      final snapshot = _build(
        financialState: _state(type: FinancialStateType.deficit, net: -100),
        behaviorFacts: _snapshot(
          facts: [
            _fact(categoryId: 'restaurant', amount: 50),
            _fact(
              categoryId: 'rent',
              stableKey: CategoryStableKey.expenseHousingRent,
              amount: 900,
              distributionRole:
                  CategoryFinancialDistributionRole.mandatoryExpenses,
            ),
          ],
        ),
        evidenceCategoryIds: {'restaurant'},
      );

      expect(
        snapshot.contributors.map((contributor) => contributor.categoryId),
        ['restaurant'],
      );
    });

    test(
      'unrelated category evidence does not include unrelated contributors',
      () {
        final snapshot = _build(
          financialState: _state(type: FinancialStateType.deficit, net: -100),
          behaviorFacts: _snapshot(
            facts: [
              _fact(categoryId: 'restaurant', amount: 50),
              _fact(
                categoryId: 'flexible',
                amount: 30,
                distributionRole:
                    CategoryFinancialDistributionRole.flexibleExpenses,
              ),
            ],
          ),
          evidenceCategoryIds: {'restaurant', 'unrelated'},
        );

        expect(
          snapshot.contributors.map((contributor) => contributor.categoryId),
          ['restaurant'],
        );
      },
    );

    test('primaryProblem null returns empty deficit contributors', () {
      final snapshot = _build(
        financialState: _state(type: FinancialStateType.deficit, net: -100),
        behaviorFacts: _snapshot(facts: [_fact(categoryId: 'restaurant')]),
        includeProblemEvidence: false,
      );

      expect(snapshot.contributors, isEmpty);
    });

    test('excludes unsupported facts and context-dependent categories', () {
      final snapshot = _build(
        financialState: _state(type: FinancialStateType.deficit, net: -10),
        behaviorFacts: _snapshot(
          facts: [
            _fact(categoryId: 'allowed', amount: 10),
            _fact(
              categoryId: 'asset-building',
              kind: FinancialBehaviorFactKind.assetBuilding,
              stableKey: CategoryStableKey.expenseFinanceSavings,
              amount: 100,
            ),
            _fact(
              categoryId: 'debt',
              kind: FinancialBehaviorFactKind.debtReduction,
              stableKey: CategoryStableKey.expenseFinanceDebtRepayment,
              amount: 100,
            ),
            _fact(
              categoryId: 'cash',
              kind: FinancialBehaviorFactKind.cashMovement,
              stableKey: CategoryStableKey.expenseOtherCashWithdrawal,
              amount: 100,
            ),
            _fact(
              categoryId: 'adjustment',
              kind: FinancialBehaviorFactKind.dataAdjustment,
              stableKey: CategoryStableKey.expenseOtherAdjustment,
              amount: 100,
            ),
            _fact(
              categoryId: 'asset-building-role',
              distributionRole: CategoryFinancialDistributionRole.assetBuilding,
              amount: 100,
            ),
            _fact(
              categoryId: 'debt-role',
              distributionRole: CategoryFinancialDistributionRole.debtReduction,
              amount: 100,
            ),
            _fact(
              categoryId: 'cash-role',
              distributionRole: CategoryFinancialDistributionRole.cashMovement,
              amount: 100,
            ),
            _fact(
              categoryId: 'adjustment-role',
              distributionRole:
                  CategoryFinancialDistributionRole.dataAdjustment,
              amount: 100,
            ),
            _fact(
              categoryId: 'context-role',
              distributionRole:
                  CategoryFinancialDistributionRole.contextDependent,
              amount: 100,
            ),
            _fact(
              categoryId: 'unresolved',
              kind: FinancialBehaviorFactKind.unresolved,
              amount: 100,
            ),
            _fact(
              categoryId: 'requires-context',
              requiresTransactionContext: true,
              amount: 100,
            ),
            _fact(
              categoryId: 'requires-evidence',
              stableKey: CategoryStableKey.expenseFinanceCurrencyExchange,
              distributionRole:
                  CategoryFinancialDistributionRole.flexibleExpenses,
              amount: 100,
            ),
          ],
        ),
      );

      expect(
        snapshot.contributors.map((contributor) => contributor.categoryId),
        ['allowed'],
      );
      expect(snapshot.coveredAmount, 10);
    });

    test(
      'includes mandatory expenses with evidence as explanatory contributors',
      () {
        final snapshot = _build(
          financialState: _state(type: FinancialStateType.deficit, net: -50),
          behaviorFacts: _snapshot(
            facts: [
              _fact(categoryId: 'restaurant', amount: 50),
              _fact(
                categoryId: 'rent',
                stableKey: CategoryStableKey.expenseHousingRent,
                amount: 900,
                distributionRole:
                    CategoryFinancialDistributionRole.mandatoryExpenses,
              ),
            ],
          ),
          evidenceCategoryIds: {'rent'},
        );

        expect(
          snapshot.contributors.map((contributor) => contributor.categoryId),
          contains('rent'),
        );
        expect(
          snapshot.contributors
              .singleWhere((contributor) => contributor.categoryId == 'rent')
              .distributionRole,
          CategoryFinancialDistributionRole.mandatoryExpenses,
        );
      },
    );

    test(
      'returns all relevant contributors after required amount is reached',
      () {
        final snapshot = _build(
          financialState: _state(type: FinancialStateType.deficit, net: -120),
          behaviorFacts: _snapshot(
            facts: [
              _fact(categoryId: 'wants-large', amount: 100),
              _fact(
                categoryId: 'flexible-small',
                amount: 30,
                distributionRole:
                    CategoryFinancialDistributionRole.flexibleExpenses,
              ),
              _fact(
                categoryId: 'mandatory-large',
                amount: 100,
                distributionRole:
                    CategoryFinancialDistributionRole.mandatoryExpenses,
              ),
            ],
          ),
        );

        expect(
          snapshot.contributors
              .map((contributor) => contributor.categoryId)
              .toSet(),
          {'wants-large', 'flexible-small', 'mandatory-large'},
        );
        expect(snapshot.coveredAmount, 230);
        expect(snapshot.isCoverageComplete, isTrue);
      },
    );

    test('recovery fields do not determine contributor list composition', () {
      final facts = [
        _fact(categoryId: 'restaurant', amount: 100),
        _fact(
          categoryId: 'flexible',
          amount: 30,
          distributionRole: CategoryFinancialDistributionRole.flexibleExpenses,
        ),
        _fact(
          categoryId: 'mandatory',
          stableKey: CategoryStableKey.expenseHousingRent,
          amount: 900,
          distributionRole: CategoryFinancialDistributionRole.mandatoryExpenses,
        ),
      ];
      final alreadyCovered = _build(
        financialState: _state(type: FinancialStateType.deficit, net: -80),
        behaviorFacts: _snapshot(facts: facts),
      );
      final notCovered = _build(
        financialState: _state(type: FinancialStateType.deficit, net: -1200),
        behaviorFacts: _snapshot(facts: facts),
      );

      expect(
        alreadyCovered.contributors
            .map((contributor) => contributor.categoryId)
            .toSet(),
        {'restaurant', 'flexible', 'mandatory'},
      );
      expect(
        notCovered.contributors
            .map((contributor) => contributor.categoryId)
            .toSet(),
        {'restaurant', 'flexible', 'mandatory'},
      );
    });

    test('returns all eligible contributors when coverage is insufficient', () {
      final snapshot = _build(
        financialState: _state(type: FinancialStateType.deficit, net: -300),
        behaviorFacts: _snapshot(
          facts: [
            _fact(categoryId: 'first', amount: 100),
            _fact(categoryId: 'second', amount: 50),
          ],
        ),
      );

      expect(snapshot.contributors, hasLength(2));
      expect(snapshot.coveredAmount, 150);
      expect(snapshot.isCoverageComplete, isFalse);
    });

    test('percentages are null when income or expenses are non-positive', () {
      final snapshot = _build(
        financialState: _state(
          type: FinancialStateType.deficit,
          income: 0,
          expenses: 0,
          net: -10,
        ),
        behaviorFacts: _snapshot(facts: [_fact(amount: 10)]),
      );

      expect(snapshot.contributors.single.percentOfIncome, isNull);
      expect(snapshot.contributors.single.percentOfExpenses, isNull);
    });

    test('mixed currency or null currency disables contributor coverage', () {
      final nullCurrency = _build(
        financialState: _state(
          type: FinancialStateType.deficit,
          currencyCode: null,
          net: -100,
        ),
        behaviorFacts: _snapshot(facts: [_fact(amount: 100)]),
      );
      final mixedCurrency = _build(
        financialState: _state(
          type: FinancialStateType.fragileBalance,
          net: -100,
          limitations: const [FinancialModelLimitation.mixedCurrencies],
        ),
        behaviorFacts: _snapshot(facts: [_fact(amount: 100)]),
      );

      for (final snapshot in [nullCurrency, mixedCurrency]) {
        expect(snapshot.contributors, isEmpty);
        expect(snapshot.coveredAmount, 0);
        expect(snapshot.isCoverageComplete, isFalse);
      }
    });
  });
}

FinancialStateCategoryContributorsSnapshot _build({
  required FinancialState financialState,
  FinancialBehaviorFactsSnapshot? behaviorFacts,
  Set<String>? evidenceCategoryIds,
  bool includeProblemEvidence = true,
  FinancialProblem? primaryProblem,
  List<FinancialDeviation>? deviations,
  FinancialFactsSnapshot? financialFacts,
}) {
  final resolvedBehaviorFacts = behaviorFacts ?? _snapshot();
  final evidenceFixture = includeProblemEvidence
      ? _evidenceFixture(
          categoryIds:
              evidenceCategoryIds ?? _categoryIdsFrom(resolvedBehaviorFacts),
        )
      : null;

  return const FinancialStateCategoryContributorsService().build(
    financialState: financialState,
    behaviorFacts: resolvedBehaviorFacts,
    primaryProblem: primaryProblem ?? evidenceFixture?.primaryProblem,
    deviations: deviations ?? evidenceFixture?.deviations ?? const [],
    financialFacts:
        financialFacts ??
        evidenceFixture?.financialFacts ??
        const FinancialFactsSnapshot(facts: [], dataGaps: []),
  );
}

Set<String> _categoryIdsFrom(FinancialBehaviorFactsSnapshot snapshot) {
  final categoryIds = <String>{};
  for (final fact in snapshot.facts) {
    final categoryId = fact.categoryId;
    if (categoryId != null && categoryId.isNotEmpty) {
      categoryIds.add(categoryId);
    }
  }
  return categoryIds;
}

_ProblemEvidenceFixture _evidenceFixture({required Set<String> categoryIds}) {
  final facts = <FinancialFact>[];
  final factIds = <String>[];
  var index = 0;

  for (final categoryId in categoryIds) {
    final factId = 'fact-$index';
    facts.add(_financialFact(id: factId, categoryId: categoryId));
    factIds.add(factId);
    index += 1;
  }

  return _ProblemEvidenceFixture(
    primaryProblem: _problem(sourceDeviationIds: const ['deviation']),
    deviations: [_deviation(sourceFactIds: factIds)],
    financialFacts: FinancialFactsSnapshot(facts: facts, dataGaps: const []),
  );
}

FinancialState _state({
  required FinancialStateType type,
  double income = 1000,
  double expenses = 800,
  double net = 200,
  String? currencyCode = 'CAD',
  List<FinancialModelLimitation> limitations = const [],
}) {
  return FinancialState(
    type: type,
    confidence: FinancialStateConfidence.high,
    period: FinancialModelPeriod(
      start: DateTime.utc(2035, 6),
      end: DateTime.utc(2035, 7),
    ),
    currencyCode: currencyCode,
    income: income,
    expenses: expenses,
    net: net,
    evidenceModelIds: const ['model'],
    limitations: limitations,
  );
}

FinancialBehaviorFactsSnapshot _snapshot({
  List<FinancialBehaviorFact> facts = const [],
}) {
  return FinancialBehaviorFactsSnapshot(facts: facts);
}

FinancialBehaviorFact _fact({
  String operationId = 'operation',
  String? categoryId = 'category',
  CategoryStableKey? stableKey = CategoryStableKey.expenseFoodRestaurant,
  double amount = 1,
  String currencyCode = 'CAD',
  FinancialBehaviorFactKind kind = FinancialBehaviorFactKind.ordinarySpending,
  CategoryFinancialDistributionRole? distributionRole =
      CategoryFinancialDistributionRole.wants,
  bool requiresTransactionContext = false,
}) {
  return FinancialBehaviorFact(
    operationId: operationId,
    operationType: OperationType.expense,
    categoryId: categoryId,
    stableKey: stableKey,
    amount: amount,
    currencyCode: currencyCode,
    occurredAt: DateTime.utc(2035, 6, 10),
    kind: kind,
    distributionRole: distributionRole,
    requiresTransactionContext: requiresTransactionContext,
  );
}

FinancialBehaviorFact _positiveFact() {
  return _fact(
    categoryId: 'savings',
    stableKey: CategoryStableKey.expenseFinanceSavings,
    amount: 150,
    kind: FinancialBehaviorFactKind.assetBuilding,
    distributionRole: CategoryFinancialDistributionRole.assetBuilding,
  );
}

FinancialProblem _problem({required List<String> sourceDeviationIds}) {
  return FinancialProblem(
    problemId: 'problem',
    problemType: FinancialProblemType.cashFlowDeficit,
    status: FinancialProblemStatus.detected,
    severity: FinancialProblemSeverity.high,
    confidence: FinancialProblemConfidence.high,
    impact: FinancialProblemImpact.cashFlow,
    period: FinancialModelPeriod(
      start: DateTime.utc(2035, 6),
      end: DateTime.utc(2035, 7),
    ),
    signals: const [],
    evidence: FinancialProblemEvidence(
      sourceDeviationIds: sourceDeviationIds,
      sourceDeviationTypes: const [FinancialDeviationType.negativeNetCashFlow],
      sourceModelIds: const ['model'],
    ),
    limitations: const [],
    metadata: FinancialProblemMetadata(
      calculatedAt: DateTime.utc(2035, 6, 30),
      engineVersion: 'test',
      ruleId: 'rule',
    ),
  );
}

FinancialDeviation _deviation({required List<String> sourceFactIds}) {
  return FinancialDeviation(
    deviationId: 'deviation',
    deviationType: FinancialDeviationType.negativeNetCashFlow,
    status: FinancialDeviationStatus.calculated,
    severity: FinancialDeviationSeverity.high,
    actualValue: -100,
    expectedValue: const FinancialDeviationExpectedValue(
      thresholdValue: 0,
      unit: FinancialModelUnit.money,
      isUpperBound: false,
    ),
    deviationAmount: 100,
    unit: FinancialModelUnit.money,
    period: FinancialModelPeriod(
      start: DateTime.utc(2035, 6),
      end: DateTime.utc(2035, 7),
    ),
    confidence: FinancialDeviationConfidence.high,
    evidence: FinancialDeviationEvidence(
      sourceModelIds: const ['model'],
      sourceModelEvidenceFactIds: sourceFactIds,
    ),
    limitations: const [],
    metadata: FinancialDeviationMetadata(
      calculatedAt: DateTime.utc(2035, 6, 30),
      engineVersion: 'test',
      thresholdId: 'threshold',
    ),
  );
}

FinancialFact _financialFact({required String id, required String categoryId}) {
  return FinancialFact(
    id: id,
    type: FinancialFactType.expenseOperation,
    source: FinancialFactSource.manualRecorded,
    confidence: FinancialFactConfidence.high,
    categoryId: categoryId,
  );
}

final class _ProblemEvidenceFixture {
  const _ProblemEvidenceFixture({
    required this.primaryProblem,
    required this.deviations,
    required this.financialFacts,
  });

  final FinancialProblem primaryProblem;
  final List<FinancialDeviation> deviations;
  final FinancialFactsSnapshot financialFacts;
}
