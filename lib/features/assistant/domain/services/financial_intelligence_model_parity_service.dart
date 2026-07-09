import '../../../categories/domain/enums/category_analytics_group.dart';
import '../entities/financial_intelligence_model_parity_metric.dart';
import '../entities/financial_intelligence_model_parity_metric_result.dart';
import '../entities/financial_intelligence_model_parity_snapshot.dart';
import '../entities/financial_intelligence_model_parity_status.dart';
import '../entities/financial_intelligence_model_type.dart';
import '../entities/financial_intelligence_models_snapshot.dart';
import '../entities/financial_model_result.dart';
import '../entities/financial_model_status.dart';
import '../entities/financial_model_type.dart';

final class FinancialIntelligenceModelParityService {
  const FinancialIntelligenceModelParityService();

  FinancialIntelligenceModelParitySnapshot compare({
    required List<FinancialModelResult> legacyModelResults,
    required double intelligenceIncomeDenominator,
    required FinancialIntelligenceModelsSnapshot intelligenceModels,
  }) {
    final legacyByType = {
      for (final result in legacyModelResults) result.modelType: result,
    };
    final legacyValues = _legacyValues(legacyByType);
    final intelligenceValues = _intelligenceValues(
      incomeDenominator: intelligenceIncomeDenominator,
      models: intelligenceModels,
    );
    final results = [
      _direct(
        metric: FinancialIntelligenceModelParityMetric.income,
        legacyValue:
            legacyValues[FinancialIntelligenceModelParityMetric.income],
        intelligenceValue:
            intelligenceValues[FinancialIntelligenceModelParityMetric.income],
      ),
      _direct(
        metric: FinancialIntelligenceModelParityMetric.ordinarySpending,
        legacyValue:
            legacyValues[FinancialIntelligenceModelParityMetric
                .ordinarySpending],
        intelligenceValue:
            intelligenceValues[FinancialIntelligenceModelParityMetric
                .ordinarySpending],
      ),
      _equivalent(
        metric: FinancialIntelligenceModelParityMetric.mandatorySpending,
        legacyValue:
            legacyValues[FinancialIntelligenceModelParityMetric
                .mandatorySpending],
        intelligenceValue:
            intelligenceValues[FinancialIntelligenceModelParityMetric
                .mandatorySpending],
      ),
      _equivalent(
        metric: FinancialIntelligenceModelParityMetric.reducibleSpending,
        legacyValue:
            legacyValues[FinancialIntelligenceModelParityMetric
                .reducibleSpending],
        intelligenceValue:
            intelligenceValues[FinancialIntelligenceModelParityMetric
                .reducibleSpending],
      ),
      _equivalent(
        metric: FinancialIntelligenceModelParityMetric.discretionarySpending,
        legacyValue:
            legacyValues[FinancialIntelligenceModelParityMetric
                .discretionarySpending],
        intelligenceValue:
            intelligenceValues[FinancialIntelligenceModelParityMetric
                .discretionarySpending],
      ),
      _unsupported(
        metric: FinancialIntelligenceModelParityMetric.assetBuilding,
        legacyValue:
            legacyValues[FinancialIntelligenceModelParityMetric.assetBuilding],
        intelligenceValue:
            intelligenceValues[FinancialIntelligenceModelParityMetric
                .assetBuilding],
      ),
      _unsupported(
        metric: FinancialIntelligenceModelParityMetric.debtReduction,
        legacyValue:
            legacyValues[FinancialIntelligenceModelParityMetric.debtReduction],
        intelligenceValue:
            intelligenceValues[FinancialIntelligenceModelParityMetric
                .debtReduction],
      ),
    ];

    return FinancialIntelligenceModelParitySnapshot(
      legacyModelValues: legacyValues,
      intelligenceModelValues: intelligenceValues,
      metricResults: results,
      matchedMetrics: results
          .where(
            (result) =>
                result.status == FinancialIntelligenceModelParityStatus.equal ||
                result.status ==
                    FinancialIntelligenceModelParityStatus.equivalent,
          )
          .toList(growable: false),
      missingMetrics: results
          .where(
            (result) =>
                result.status ==
                FinancialIntelligenceModelParityStatus.unsupported,
          )
          .toList(growable: false),
      intentionallyDivergentMetrics: results
          .where(
            (result) =>
                result.status ==
                FinancialIntelligenceModelParityStatus.intentionallyDifferent,
          )
          .toList(growable: false),
    );
  }

  Map<FinancialIntelligenceModelParityMetric, double?> _legacyValues(
    Map<FinancialModelType, FinancialModelResult> legacyByType,
  ) {
    return {
      FinancialIntelligenceModelParityMetric.income: _modelValue(
        legacyByType[FinancialModelType.incomeTotal],
      ),
      FinancialIntelligenceModelParityMetric.ordinarySpending: _modelValue(
        legacyByType[FinancialModelType.expenseTotal],
      ),
      FinancialIntelligenceModelParityMetric.mandatorySpending:
          _analyticsGroupTotal(
            legacyByType,
            CategoryAnalyticsGroup.essentialExpenses,
          ),
      FinancialIntelligenceModelParityMetric.reducibleSpending:
          _analyticsGroupTotal(
            legacyByType,
            CategoryAnalyticsGroup.flexibleExpenses,
          ),
      FinancialIntelligenceModelParityMetric.discretionarySpending:
          _analyticsGroupTotal(
            legacyByType,
            CategoryAnalyticsGroup.lifestyleEntertainment,
          ),
      FinancialIntelligenceModelParityMetric.assetBuilding: null,
      FinancialIntelligenceModelParityMetric.debtReduction: null,
    };
  }

  Map<FinancialIntelligenceModelParityMetric, double?> _intelligenceValues({
    required double incomeDenominator,
    required FinancialIntelligenceModelsSnapshot models,
  }) {
    return {
      FinancialIntelligenceModelParityMetric.income: incomeDenominator,
      FinancialIntelligenceModelParityMetric.ordinarySpending: models.valueFor(
        FinancialIntelligenceModelType.ordinarySpendingTotal,
      ),
      FinancialIntelligenceModelParityMetric.mandatorySpending: models.valueFor(
        FinancialIntelligenceModelType.mandatorySpendingTotal,
      ),
      FinancialIntelligenceModelParityMetric.reducibleSpending: models.valueFor(
        FinancialIntelligenceModelType.flexibleSpendingTotal,
      ),
      FinancialIntelligenceModelParityMetric.discretionarySpending: models
          .valueFor(FinancialIntelligenceModelType.discretionarySpendingTotal),
      FinancialIntelligenceModelParityMetric.assetBuilding: models.valueFor(
        FinancialIntelligenceModelType.assetBuildingTotal,
      ),
      FinancialIntelligenceModelParityMetric.debtReduction: models.valueFor(
        FinancialIntelligenceModelType.debtReductionTotal,
      ),
    };
  }

  double? _modelValue(FinancialModelResult? result) {
    if (result?.status != FinancialModelStatus.calculated) {
      return null;
    }
    return result?.value;
  }

  double? _analyticsGroupTotal(
    Map<FinancialModelType, FinancialModelResult> legacyByType,
    CategoryAnalyticsGroup group,
  ) {
    final result = legacyByType[FinancialModelType.expenseAnalyticsGroupTotals];
    if (result?.status != FinancialModelStatus.calculated) {
      return null;
    }
    var total = 0.0;
    for (final item in result!.breakdown) {
      if (item.assumptions.contains('analyticsGroup:${group.name}')) {
        total += item.value ?? 0.0;
      }
    }
    return total;
  }

  FinancialIntelligenceModelParityMetricResult _direct({
    required FinancialIntelligenceModelParityMetric metric,
    required double? legacyValue,
    required double? intelligenceValue,
  }) {
    return _result(
      metric: metric,
      legacyValue: legacyValue,
      intelligenceValue: intelligenceValue,
      matchedStatus: FinancialIntelligenceModelParityStatus.equal,
    );
  }

  FinancialIntelligenceModelParityMetricResult _equivalent({
    required FinancialIntelligenceModelParityMetric metric,
    required double? legacyValue,
    required double? intelligenceValue,
  }) {
    return _result(
      metric: metric,
      legacyValue: legacyValue,
      intelligenceValue: intelligenceValue,
      matchedStatus: FinancialIntelligenceModelParityStatus.equivalent,
    );
  }

  FinancialIntelligenceModelParityMetricResult _unsupported({
    required FinancialIntelligenceModelParityMetric metric,
    required double? legacyValue,
    required double? intelligenceValue,
  }) {
    return FinancialIntelligenceModelParityMetricResult(
      metric: metric,
      status: FinancialIntelligenceModelParityStatus.unsupported,
      legacyValue: legacyValue,
      intelligenceValue: intelligenceValue,
    );
  }

  FinancialIntelligenceModelParityMetricResult _result({
    required FinancialIntelligenceModelParityMetric metric,
    required double? legacyValue,
    required double? intelligenceValue,
    required FinancialIntelligenceModelParityStatus matchedStatus,
  }) {
    final status = legacyValue == null || intelligenceValue == null
        ? FinancialIntelligenceModelParityStatus.unsupported
        : _same(legacyValue, intelligenceValue)
        ? matchedStatus
        : FinancialIntelligenceModelParityStatus.intentionallyDifferent;

    return FinancialIntelligenceModelParityMetricResult(
      metric: metric,
      status: status,
      legacyValue: legacyValue,
      intelligenceValue: intelligenceValue,
    );
  }

  bool _same(double left, double right) {
    return (left - right).abs() < 0.000001;
  }
}
