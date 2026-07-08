import '../../../categories/domain/enums/category_analytics_group.dart';
import '../entities/financial_model_confidence.dart';
import '../entities/financial_model_limitation.dart';
import '../entities/financial_model_period.dart';
import '../entities/financial_model_result.dart';
import '../entities/financial_model_status.dart';
import '../entities/financial_model_type.dart';
import '../entities/financial_period_distribution.dart';
import '../entities/financial_period_distribution_bucket.dart';
import '../entities/financial_period_distribution_item.dart';

final class FinancialPeriodDistributionService {
  const FinancialPeriodDistributionService();

  FinancialPeriodDistribution build(List<FinancialModelResult> modelResults) {
    final byType = {
      for (final result in modelResults) result.modelType: result,
    };
    final income = byType[FinancialModelType.incomeTotal];
    final expenseGroups =
        byType[FinancialModelType.expenseAnalyticsGroupTotals];
    final net = byType[FinancialModelType.netCashFlow];
    final expense = byType[FinancialModelType.expenseTotal];
    final period = _periodFrom([income, expense, net, expenseGroups]);
    final currencyCode = _currencyCode([income, expense, net, expenseGroups]);
    final limitations = <FinancialModelLimitation>{
      if (income != null) ...income.limitations,
      if (expense != null) ...expense.limitations,
      if (expenseGroups != null) ...expenseGroups.limitations,
      if (net != null) ...net.limitations,
    };
    final incomeValue = _value(income);
    final expenseValue = _value(expense) ?? 0.0;
    final netValue = _value(net) ?? 0.0;

    if (incomeValue == null || incomeValue <= 0) {
      limitations.add(FinancialModelLimitation.zeroIncome);
      return FinancialPeriodDistribution(
        period: period,
        currencyCode: currencyCode,
        incomeTotal: incomeValue ?? 0.0,
        expenseTotal: expenseValue,
        netCashFlow: netValue,
        items: _items(
          income: incomeValue ?? 0.0,
          mandatory: 0.0,
          flexible: 0.0,
          wants: 0.0,
          savings: 0.0,
          limitations: limitations,
        ),
        confidence: FinancialModelConfidence.none,
        evidenceModelIds: _evidenceIds([income, expense, net, expenseGroups]),
        limitations: limitations.toList(growable: false),
      );
    }

    final groupTotals = _groupTotals(expenseGroups);
    final mandatory =
        groupTotals[CategoryAnalyticsGroup.essentialExpenses] ?? 0.0;
    final flexible =
        groupTotals[CategoryAnalyticsGroup.flexibleExpenses] ?? 0.0;
    final wants =
        groupTotals[CategoryAnalyticsGroup.lifestyleEntertainment] ?? 0.0;
    final savings = netValue > 0 ? netValue : 0.0;
    final rawAllocated = mandatory + flexible + wants + savings;
    if (incomeValue - rawAllocated < 0) {
      limitations.add(FinancialModelLimitation.derivedNegativeAmount);
    }

    return FinancialPeriodDistribution(
      period: period,
      currencyCode: currencyCode,
      incomeTotal: incomeValue,
      expenseTotal: expenseValue,
      netCashFlow: netValue,
      items: _items(
        income: incomeValue,
        mandatory: mandatory,
        flexible: flexible,
        wants: wants,
        savings: savings,
        limitations: limitations,
      ),
      confidence: _confidence([
        income,
        expense,
        net,
        expenseGroups,
      ], limitations),
      evidenceModelIds: _evidenceIds([income, expense, net, expenseGroups]),
      limitations: limitations.toList(growable: false),
    );
  }

  List<FinancialPeriodDistributionItem> _items({
    required double income,
    required double mandatory,
    required double flexible,
    required double wants,
    required double savings,
    required Set<FinancialModelLimitation> limitations,
  }) {
    return [
      _item(
        FinancialPeriodDistributionBucket.mandatoryExpenses,
        mandatory,
        income,
      ),
      _item(
        FinancialPeriodDistributionBucket.flexibleExpenses,
        flexible,
        income,
      ),
      _item(FinancialPeriodDistributionBucket.wants, wants, income),
      _item(
        FinancialPeriodDistributionBucket.savings,
        savings,
        income,
        limitations:
            limitations.contains(FinancialModelLimitation.derivedNegativeAmount)
            ? const [FinancialModelLimitation.derivedNegativeAmount]
            : const [],
      ),
    ];
  }

  FinancialPeriodDistributionItem _item(
    FinancialPeriodDistributionBucket bucket,
    double amount,
    double income, {
    List<FinancialModelLimitation> limitations = const [],
  }) {
    final safeAmount = amount < 0 ? 0.0 : amount;
    return FinancialPeriodDistributionItem(
      bucket: bucket,
      amount: safeAmount,
      percent: income <= 0 ? 0.0 : safeAmount / income,
      limitations: limitations,
    );
  }

  Map<CategoryAnalyticsGroup, double> _groupTotals(
    FinancialModelResult? result,
  ) {
    if (result?.status != FinancialModelStatus.calculated) {
      return const {};
    }
    final totals = <CategoryAnalyticsGroup, double>{};
    for (final item in result!.breakdown) {
      final group = _groupFromAssumptions(item.assumptions);
      if (group == null) {
        continue;
      }
      totals[group] = (totals[group] ?? 0.0) + (item.value ?? 0.0);
    }
    return totals;
  }

  CategoryAnalyticsGroup? _groupFromAssumptions(List<String> assumptions) {
    for (final assumption in assumptions) {
      if (!assumption.startsWith('analyticsGroup:')) {
        continue;
      }
      final name = assumption.substring('analyticsGroup:'.length);
      for (final group in CategoryAnalyticsGroup.values) {
        if (group.name == name) {
          return group;
        }
      }
    }
    return null;
  }

  FinancialModelConfidence _confidence(
    List<FinancialModelResult?> keyModels,
    Set<FinancialModelLimitation> limitations,
  ) {
    if (keyModels.any(
          (model) => model?.status != FinancialModelStatus.calculated,
        ) ||
        limitations.contains(FinancialModelLimitation.mixedCurrencies)) {
      return FinancialModelConfidence.none;
    }
    if (limitations.contains(FinancialModelLimitation.noMatchingFacts) ||
        limitations.contains(FinancialModelLimitation.zeroIncome)) {
      return FinancialModelConfidence.low;
    }
    if (limitations.isNotEmpty) {
      return FinancialModelConfidence.medium;
    }
    return FinancialModelConfidence.high;
  }

  double? _value(FinancialModelResult? model) {
    if (model?.status != FinancialModelStatus.calculated) {
      return null;
    }
    return model?.value;
  }

  List<String> _evidenceIds(List<FinancialModelResult?> models) {
    return [
      for (final model in models)
        if (model != null) model.modelId,
    ];
  }

  String? _currencyCode(List<FinancialModelResult?> models) {
    for (final model in models) {
      if (model?.currencyCode != null) {
        return model!.currencyCode;
      }
    }
    return null;
  }

  FinancialModelPeriod _periodFrom(List<FinancialModelResult?> models) {
    for (final model in models) {
      if (model != null) {
        return model.period;
      }
    }
    throw StateError(
      'FinancialPeriodDistribution requires at least one model result.',
    );
  }
}
