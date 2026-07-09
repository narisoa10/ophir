import 'package:flutter_test/flutter_test.dart';
import 'package:ophir/features/assistant/domain/entities/financial_intelligence_model.dart';
import 'package:ophir/features/assistant/domain/entities/financial_intelligence_model_parity_metric.dart';
import 'package:ophir/features/assistant/domain/entities/financial_intelligence_model_parity_metric_result.dart';
import 'package:ophir/features/assistant/domain/entities/financial_intelligence_model_parity_status.dart';
import 'package:ophir/features/assistant/domain/entities/financial_intelligence_model_type.dart';
import 'package:ophir/features/assistant/domain/entities/financial_intelligence_models_snapshot.dart';
import 'package:ophir/features/assistant/domain/entities/financial_model_confidence.dart';
import 'package:ophir/features/assistant/domain/entities/financial_model_evidence.dart';
import 'package:ophir/features/assistant/domain/entities/financial_model_limitation.dart';
import 'package:ophir/features/assistant/domain/entities/financial_model_metadata.dart';
import 'package:ophir/features/assistant/domain/entities/financial_model_period.dart';
import 'package:ophir/features/assistant/domain/entities/financial_model_result.dart';
import 'package:ophir/features/assistant/domain/entities/financial_model_status.dart';
import 'package:ophir/features/assistant/domain/entities/financial_model_type.dart';
import 'package:ophir/features/assistant/domain/entities/financial_model_unit.dart';
import 'package:ophir/features/assistant/domain/services/financial_intelligence_model_parity_service.dart';

void main() {
  const service = FinancialIntelligenceModelParityService();

  group('FinancialIntelligenceModelParityService', () {
    test('creates immutable parity snapshot', () {
      final snapshot = service.compare(
        legacyModelResults: _legacyModels(),
        intelligenceIncomeDenominator: 5000,
        intelligenceModels: _intelligenceModels(),
      );

      expect(snapshot.metricResults, hasLength(7));
      expect(
        snapshot.legacyModelValues[FinancialIntelligenceModelParityMetric
            .income],
        5000,
      );
      expect(
        snapshot.intelligenceModelValues[FinancialIntelligenceModelParityMetric
            .ordinarySpending],
        1600,
      );
      expect(
        () => snapshot.metricResults.add(
          const FinancialIntelligenceModelParityMetricResult(
            metric: FinancialIntelligenceModelParityMetric.income,
            status: FinancialIntelligenceModelParityStatus.equal,
            legacyValue: 0,
            intelligenceValue: 0,
          ),
        ),
        throwsUnsupportedError,
      );
    });

    test('marks directly matching metrics as equal', () {
      final snapshot = service.compare(
        legacyModelResults: _legacyModels(),
        intelligenceIncomeDenominator: 5000,
        intelligenceModels: _intelligenceModels(),
      );

      expect(
        snapshot
            .resultFor(FinancialIntelligenceModelParityMetric.income)
            .status,
        FinancialIntelligenceModelParityStatus.equal,
      );
      expect(
        snapshot
            .resultFor(FinancialIntelligenceModelParityMetric.ordinarySpending)
            .status,
        FinancialIntelligenceModelParityStatus.equal,
      );
    });

    test('marks mapped category metrics as equivalent', () {
      final snapshot = service.compare(
        legacyModelResults: _legacyModels(),
        intelligenceIncomeDenominator: 5000,
        intelligenceModels: _intelligenceModels(),
      );

      expect(
        snapshot
            .resultFor(FinancialIntelligenceModelParityMetric.mandatorySpending)
            .status,
        FinancialIntelligenceModelParityStatus.equivalent,
      );
      expect(
        snapshot
            .resultFor(FinancialIntelligenceModelParityMetric.reducibleSpending)
            .status,
        FinancialIntelligenceModelParityStatus.equivalent,
      );
      expect(
        snapshot
            .resultFor(
              FinancialIntelligenceModelParityMetric.discretionarySpending,
            )
            .status,
        FinancialIntelligenceModelParityStatus.equivalent,
      );
    });

    test('marks ordinary spending divergence as intentionally different', () {
      final snapshot = service.compare(
        legacyModelResults: _legacyModels(expenseTotal: 2100),
        intelligenceIncomeDenominator: 5000,
        intelligenceModels: _intelligenceModels(),
      );
      final result = snapshot.resultFor(
        FinancialIntelligenceModelParityMetric.ordinarySpending,
      );

      expect(
        result.status,
        FinancialIntelligenceModelParityStatus.intentionallyDifferent,
      );
      expect(snapshot.intentionallyDivergentMetrics, contains(result));
    });

    test('marks metrics without legacy counterparts as unsupported', () {
      final snapshot = service.compare(
        legacyModelResults: _legacyModels(),
        intelligenceIncomeDenominator: 5000,
        intelligenceModels: _intelligenceModels(assetBuilding: 300, debt: 600),
      );
      final assetBuilding = snapshot.resultFor(
        FinancialIntelligenceModelParityMetric.assetBuilding,
      );
      final debtReduction = snapshot.resultFor(
        FinancialIntelligenceModelParityMetric.debtReduction,
      );

      expect(
        assetBuilding.status,
        FinancialIntelligenceModelParityStatus.unsupported,
      );
      expect(
        debtReduction.status,
        FinancialIntelligenceModelParityStatus.unsupported,
      );
      expect(snapshot.missingMetrics, contains(assetBuilding));
      expect(snapshot.missingMetrics, contains(debtReduction));
    });
  });
}

List<FinancialModelResult> _legacyModels({
  double income = 5000,
  double expenseTotal = 1600,
  double mandatory = 1000,
  double reducible = 400,
  double discretionary = 200,
}) {
  return [
    _model(type: FinancialModelType.incomeTotal, value: income),
    _model(type: FinancialModelType.expenseTotal, value: expenseTotal),
    _model(
      type: FinancialModelType.expenseAnalyticsGroupTotals,
      value: mandatory + reducible + discretionary,
      breakdown: [
        _groupTotal('essentialExpenses', mandatory),
        _groupTotal('flexibleExpenses', reducible),
        _groupTotal('lifestyleEntertainment', discretionary),
      ],
    ),
  ];
}

FinancialIntelligenceModelsSnapshot _intelligenceModels({
  double ordinary = 1600,
  double mandatory = 1000,
  double reducible = 400,
  double discretionary = 200,
  double assetBuilding = 0,
  double debt = 0,
}) {
  return FinancialIntelligenceModelsSnapshot(
    models: [
      _intelligenceModel(
        FinancialIntelligenceModelType.ordinarySpendingTotal,
        ordinary,
      ),
      _intelligenceModel(
        FinancialIntelligenceModelType.mandatorySpendingTotal,
        mandatory,
      ),
      _intelligenceModel(
        FinancialIntelligenceModelType.flexibleSpendingTotal,
        reducible,
      ),
      _intelligenceModel(
        FinancialIntelligenceModelType.discretionarySpendingTotal,
        discretionary,
      ),
      _intelligenceModel(
        FinancialIntelligenceModelType.assetBuildingTotal,
        assetBuilding,
      ),
      _intelligenceModel(
        FinancialIntelligenceModelType.debtReductionTotal,
        debt,
      ),
    ],
  );
}

FinancialIntelligenceModel _intelligenceModel(
  FinancialIntelligenceModelType type,
  double value,
) {
  return FinancialIntelligenceModel(type: type, value: value, isRatio: false);
}

FinancialModelResult _groupTotal(String group, double value) {
  return _model(
    type: FinancialModelType.expenseAnalyticsGroupTotals,
    value: value,
    assumptions: ['analyticsGroup:$group'],
  );
}

FinancialModelResult _model({
  required FinancialModelType type,
  required double? value,
  FinancialModelStatus status = FinancialModelStatus.calculated,
  List<String> assumptions = const [],
  List<FinancialModelResult> breakdown = const [],
}) {
  return FinancialModelResult(
    modelId: 'model.${type.name}',
    modelType: type,
    status: status,
    value: value,
    unit: FinancialModelUnit.money,
    period: FinancialModelPeriod(
      start: DateTime.utc(2035, 6),
      end: DateTime.utc(2035, 7),
    ),
    currencyCode: 'CAD',
    dataConfidence: FinancialModelConfidence.high,
    modelConfidence: FinancialModelConfidence.high,
    evidence: const FinancialModelEvidence(factIds: [], dataGapSourceIds: []),
    assumptions: assumptions,
    limitations: const <FinancialModelLimitation>[],
    inputCoverage: 1,
    metadata: FinancialModelMetadata(
      calculatedAt: DateTime.utc(2035, 6),
      engineVersion: 'test',
      snapshotVersion: 'test',
    ),
    breakdown: breakdown,
  );
}
