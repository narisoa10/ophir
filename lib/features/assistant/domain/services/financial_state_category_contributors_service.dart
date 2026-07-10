import 'dart:math' as math;

import '../../../categories/domain/entities/category_intelligence_catalog.dart';
import '../../../categories/domain/enums/category_financial_distribution_role.dart';
import '../../../categories/domain/enums/category_stable_key.dart';
import '../../../categories/domain/enums/spending_pattern.dart';
import '../entities/financial_behavior_fact.dart';
import '../entities/financial_behavior_fact_kind.dart';
import '../entities/financial_behavior_facts_snapshot.dart';
import '../entities/financial_model_limitation.dart';
import '../entities/financial_state.dart';
import '../entities/financial_state_category_contributor.dart';
import '../entities/financial_state_category_contributors_snapshot.dart';
import '../entities/financial_state_contributor_strategy.dart';
import '../entities/financial_state_type.dart';

final class FinancialStateCategoryContributorsService {
  const FinancialStateCategoryContributorsService();

  FinancialStateCategoryContributorsSnapshot build({
    required FinancialState financialState,
    required FinancialBehaviorFactsSnapshot behaviorFacts,
  }) {
    final strategy = _strategyFor(financialState.type);
    final requiredAmount = _requiredAmountFor(financialState);

    if (!_usesContributors(financialState.type)) {
      return _snapshot(
        financialState: financialState,
        strategy: strategy,
        requiredAmount: requiredAmount,
        coveredAmount: 0,
        isCoverageComplete: true,
        contributors: const [],
      );
    }

    if (_hasMixedCurrencyRisk(financialState)) {
      return _snapshot(
        financialState: financialState,
        strategy: strategy,
        requiredAmount: requiredAmount,
        coveredAmount: 0,
        isCoverageComplete: false,
        contributors: const [],
      );
    }

    if (requiredAmount == 0) {
      return _snapshot(
        financialState: financialState,
        strategy: strategy,
        requiredAmount: requiredAmount,
        coveredAmount: 0,
        isCoverageComplete: true,
        contributors: const [],
      );
    }

    final candidates = _contributorsFor(
      facts: behaviorFacts.facts,
      financialState: financialState,
    )..sort(_compareContributors);
    final selected = <FinancialStateCategoryContributor>[];
    var coveredAmount = 0.0;

    for (final contributor in candidates) {
      selected.add(contributor);
      coveredAmount += contributor.amount;
      if (coveredAmount >= requiredAmount) {
        break;
      }
    }

    return _snapshot(
      financialState: financialState,
      strategy: strategy,
      requiredAmount: requiredAmount,
      coveredAmount: coveredAmount,
      isCoverageComplete: coveredAmount >= requiredAmount,
      contributors: selected,
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

  double _requiredAmountFor(FinancialState financialState) {
    return switch (financialState.type) {
      FinancialStateType.deficit => math.max(0.0, -financialState.net),
      FinancialStateType.fragileBalance => math.max(
        0.0,
        financialState.income * 0.10 - financialState.net,
      ),
      FinancialStateType.stable ||
      FinancialStateType.growth ||
      FinancialStateType.strongPosition => 0,
    };
  }

  bool _usesContributors(FinancialStateType stateType) {
    return switch (stateType) {
      FinancialStateType.deficit || FinancialStateType.fragileBalance => true,
      FinancialStateType.stable ||
      FinancialStateType.growth ||
      FinancialStateType.strongPosition => false,
    };
  }

  bool _hasMixedCurrencyRisk(FinancialState financialState) {
    return financialState.currencyCode == null ||
        financialState.limitations.contains(
          FinancialModelLimitation.mixedCurrencies,
        );
  }

  List<FinancialStateCategoryContributor> _contributorsFor({
    required List<FinancialBehaviorFact> facts,
    required FinancialState financialState,
  }) {
    final aggregates = <_ContributorKey, double>{};

    for (final fact in facts) {
      final categoryId = fact.categoryId;
      final stableKey = fact.stableKey;
      final distributionRole = fact.distributionRole;

      if (fact.kind != FinancialBehaviorFactKind.ordinarySpending ||
          categoryId == null ||
          stableKey == null ||
          distributionRole == null ||
          fact.requiresTransactionContext ||
          fact.currencyCode != financialState.currencyCode ||
          !_isAllowedRole(distributionRole)) {
        continue;
      }

      final profile = CategoryIntelligenceCatalog.profileFor(stableKey);
      final spendingPattern = profile?.spendingPattern;
      if (spendingPattern == null || !_isAllowedPattern(spendingPattern)) {
        continue;
      }

      final key = _ContributorKey(
        categoryId: categoryId,
        stableKey: stableKey,
        distributionRole: distributionRole,
        spendingPattern: spendingPattern,
      );
      aggregates[key] = (aggregates[key] ?? 0) + fact.amount;
    }

    return [
      for (final entry in aggregates.entries)
        FinancialStateCategoryContributor(
          categoryId: entry.key.categoryId,
          stableKey: entry.key.stableKey,
          amount: entry.value,
          percentOfIncome: _percentOf(entry.value, financialState.income),
          percentOfExpenses: _percentOf(entry.value, financialState.expenses),
          distributionRole: entry.key.distributionRole,
          spendingPattern: entry.key.spendingPattern,
        ),
    ];
  }

  bool _isAllowedRole(CategoryFinancialDistributionRole role) {
    return switch (role) {
      CategoryFinancialDistributionRole.wants ||
      CategoryFinancialDistributionRole.flexibleExpenses ||
      CategoryFinancialDistributionRole.mandatoryExpenses => true,
      CategoryFinancialDistributionRole.contextDependent ||
      CategoryFinancialDistributionRole.income ||
      CategoryFinancialDistributionRole.assetBuilding ||
      CategoryFinancialDistributionRole.debtReduction ||
      CategoryFinancialDistributionRole.cashMovement ||
      CategoryFinancialDistributionRole.dataAdjustment => false,
    };
  }

  bool _isAllowedPattern(SpendingPattern pattern) {
    return switch (pattern) {
      SpendingPattern.usuallyVariable ||
      SpendingPattern.usuallyOneOff ||
      SpendingPattern.usuallyRecurring ||
      SpendingPattern.periodic => true,
      SpendingPattern.requiresTransactionEvidence ||
      SpendingPattern.unknown => false,
    };
  }

  double? _percentOf(double amount, double total) {
    if (total <= 0) {
      return null;
    }
    return amount / total * 100;
  }

  int _compareContributors(
    FinancialStateCategoryContributor left,
    FinancialStateCategoryContributor right,
  ) {
    final roleComparison = _roleRank(
      left.distributionRole,
    ).compareTo(_roleRank(right.distributionRole));
    if (roleComparison != 0) {
      return roleComparison;
    }

    final patternComparison = _patternRank(
      left.spendingPattern,
    ).compareTo(_patternRank(right.spendingPattern));
    if (patternComparison != 0) {
      return patternComparison;
    }

    final amountComparison = right.amount.compareTo(left.amount);
    if (amountComparison != 0) {
      return amountComparison;
    }

    final stableKeyComparison = left.stableKey.name.compareTo(
      right.stableKey.name,
    );
    if (stableKeyComparison != 0) {
      return stableKeyComparison;
    }

    return left.categoryId.compareTo(right.categoryId);
  }

  int _roleRank(CategoryFinancialDistributionRole role) {
    return switch (role) {
      CategoryFinancialDistributionRole.wants => 0,
      CategoryFinancialDistributionRole.flexibleExpenses => 1,
      CategoryFinancialDistributionRole.mandatoryExpenses => 2,
      _ => 3,
    };
  }

  int _patternRank(SpendingPattern pattern) {
    return switch (pattern) {
      SpendingPattern.usuallyVariable => 0,
      SpendingPattern.usuallyOneOff => 1,
      SpendingPattern.usuallyRecurring => 2,
      SpendingPattern.periodic => 3,
      _ => 4,
    };
  }

  FinancialStateCategoryContributorsSnapshot _snapshot({
    required FinancialState financialState,
    required FinancialStateContributorStrategy strategy,
    required double requiredAmount,
    required double coveredAmount,
    required bool isCoverageComplete,
    required List<FinancialStateCategoryContributor> contributors,
  }) {
    return FinancialStateCategoryContributorsSnapshot(
      stateType: financialState.type,
      strategy: strategy,
      requiredAmount: requiredAmount,
      coveredAmount: coveredAmount,
      isCoverageComplete: isCoverageComplete,
      currencyCode: financialState.currencyCode,
      confidence: financialState.confidence,
      contributors: contributors,
      limitations: financialState.limitations,
    );
  }
}

final class _ContributorKey {
  const _ContributorKey({
    required this.categoryId,
    required this.stableKey,
    required this.distributionRole,
    required this.spendingPattern,
  });

  final String categoryId;
  final CategoryStableKey stableKey;
  final CategoryFinancialDistributionRole distributionRole;
  final SpendingPattern spendingPattern;

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is _ContributorKey &&
            other.categoryId == categoryId &&
            other.stableKey == stableKey &&
            other.distributionRole == distributionRole &&
            other.spendingPattern == spendingPattern;
  }

  @override
  int get hashCode {
    return Object.hash(
      categoryId,
      stableKey,
      distributionRole,
      spendingPattern,
    );
  }
}
