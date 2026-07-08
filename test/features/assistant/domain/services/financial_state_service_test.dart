import 'package:flutter_test/flutter_test.dart';
import 'package:ophir/features/assistant/domain/entities/financial_model_confidence.dart';
import 'package:ophir/features/assistant/domain/entities/financial_model_evidence.dart';
import 'package:ophir/features/assistant/domain/entities/financial_model_limitation.dart';
import 'package:ophir/features/assistant/domain/entities/financial_model_metadata.dart';
import 'package:ophir/features/assistant/domain/entities/financial_model_period.dart';
import 'package:ophir/features/assistant/domain/entities/financial_model_result.dart';
import 'package:ophir/features/assistant/domain/entities/financial_model_status.dart';
import 'package:ophir/features/assistant/domain/entities/financial_model_type.dart';
import 'package:ophir/features/assistant/domain/entities/financial_model_unit.dart';
import 'package:ophir/features/assistant/domain/entities/financial_state_confidence.dart';
import 'package:ophir/features/assistant/domain/entities/financial_state_type.dart';
import 'package:ophir/features/assistant/domain/services/financial_state_service.dart';

void main() {
  const service = FinancialStateService();

  test('detects deficit when net is negative', () {
    final state = service.evaluate(modelResults: _models(net: -1));

    expect(state.type, FinancialStateType.deficit);
  });

  test('detects fragile balance when margin is small', () {
    final state = service.evaluate(
      modelResults: _models(net: 5, savingsRate: 0.05, expenseRatio: 0.95),
    );

    expect(state.type, FinancialStateType.fragileBalance);
  });

  test('detects stable state', () {
    final state = service.evaluate(
      modelResults: _models(net: 15, savingsRate: 0.15, expenseRatio: 0.85),
    );

    expect(state.type, FinancialStateType.stable);
  });

  test('detects growth state', () {
    final state = service.evaluate(
      modelResults: _models(net: 25, savingsRate: 0.25, expenseRatio: 0.75),
    );

    expect(state.type, FinancialStateType.growth);
  });

  test('detects strong position state', () {
    final state = service.evaluate(
      modelResults: _models(net: 40, savingsRate: 0.40, expenseRatio: 0.60),
    );

    expect(state.type, FinancialStateType.strongPosition);
  });

  test('returns low confidence when data quality is below threshold', () {
    final state = service.evaluate(modelResults: _models(dataQuality: 59));

    expect(state.confidence, FinancialStateConfidence.low);
  });
}

List<FinancialModelResult> _models({
  double income = 100,
  double expenses = 80,
  double net = 20,
  double savingsRate = 0.20,
  double expenseRatio = 0.80,
  double dataQuality = 100,
}) {
  return [
    _model(FinancialModelType.incomeTotal, income, currencyCode: 'CAD'),
    _model(FinancialModelType.expenseTotal, expenses, currencyCode: 'CAD'),
    _model(FinancialModelType.netCashFlow, net, currencyCode: 'CAD'),
    _model(FinancialModelType.savingsRate, savingsRate),
    _model(FinancialModelType.expenseToIncomeRatio, expenseRatio),
    _model(FinancialModelType.dataQualityScore, dataQuality),
  ];
}

FinancialModelResult _model(
  FinancialModelType type,
  double value, {
  String? currencyCode,
  List<FinancialModelLimitation> limitations = const [],
}) {
  final period = FinancialModelPeriod(
    start: DateTime(2025, 5),
    end: DateTime(2025, 6),
  );
  return FinancialModelResult(
    modelId: type.name,
    modelType: type,
    status: FinancialModelStatus.calculated,
    value: value,
    unit: FinancialModelUnit.none,
    period: period,
    currencyCode: currencyCode,
    dataConfidence: FinancialModelConfidence.high,
    modelConfidence: FinancialModelConfidence.high,
    evidence: const FinancialModelEvidence(factIds: [], dataGapSourceIds: []),
    assumptions: const [],
    limitations: limitations,
    inputCoverage: 1,
    metadata: FinancialModelMetadata(
      calculatedAt: DateTime(2025, 5),
      engineVersion: 'test',
      snapshotVersion: 'test',
    ),
    breakdown: const [],
  );
}
