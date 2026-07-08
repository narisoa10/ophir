import 'package:flutter_test/flutter_test.dart';
import 'package:ophir/features/assistant/domain/entities/financial_deviation_limitation.dart';
import 'package:ophir/features/assistant/domain/entities/financial_deviation_severity.dart';
import 'package:ophir/features/assistant/domain/entities/financial_deviation_type.dart';
import 'package:ophir/features/assistant/domain/entities/financial_model_confidence.dart';
import 'package:ophir/features/assistant/domain/entities/financial_model_evidence.dart';
import 'package:ophir/features/assistant/domain/entities/financial_model_limitation.dart';
import 'package:ophir/features/assistant/domain/entities/financial_model_metadata.dart';
import 'package:ophir/features/assistant/domain/entities/financial_model_period.dart';
import 'package:ophir/features/assistant/domain/entities/financial_model_result.dart';
import 'package:ophir/features/assistant/domain/entities/financial_model_status.dart';
import 'package:ophir/features/assistant/domain/entities/financial_model_type.dart';
import 'package:ophir/features/assistant/domain/entities/financial_model_unit.dart';
import 'package:ophir/features/assistant/domain/services/financial_deviation_service.dart';
import 'package:ophir/features/assistant/domain/services/financial_deviation_threshold_catalog.dart';

const _service = FinancialDeviationService();
final _period = FinancialModelPeriod(
  start: DateTime(2026, 1),
  end: DateTime(2026, 2),
);
final _calculatedAt = DateTime(2026, 2);

void main() {
  group('FinancialDeviationService', () {
    test('detects negative net cash flow deviation', () {
      final deviations = _service.detect([
        _model(FinancialModelType.netCashFlow, -250),
      ]);

      expect(deviations, hasLength(1));
      expect(
        deviations.single.deviationType,
        FinancialDeviationType.negativeNetCashFlow,
      );
      expect(deviations.single.actualValue, -250);
      expect(deviations.single.expectedValue.thresholdValue, 0);
      expect(deviations.single.deviationAmount, 250);
      expect(deviations.single.unit, FinancialModelUnit.money);
      expect(deviations.single.period, _period);
      expect(deviations.single.evidence.sourceModelIds, [
        'financial.model.netCashFlow',
      ]);
      expect(deviations.single.evidence.sourceModelEvidenceFactIds, [
        'fact:netCashFlow',
      ]);
    });

    test('does not detect negative net cash flow at threshold', () {
      final deviations = _service.detect([
        _model(FinancialModelType.netCashFlow, 0),
      ]);

      expect(deviations, isEmpty);
    });

    test('detects high expense-to-income ratio only above threshold', () {
      final equal = _service.detect([
        _model(FinancialModelType.expenseToIncomeRatio, 0.75),
      ]);
      final above = _service.detect([
        _model(FinancialModelType.expenseToIncomeRatio, 0.76),
      ]);

      expect(equal, isEmpty);
      expect(
        above.single.deviationType,
        FinancialDeviationType.highExpenseToIncomeRatio,
      );
      expect(above.single.deviationAmount, closeTo(0.01, 0.0001));
    });

    test('detects low savings rate only below threshold', () {
      final equal = _service.detect([
        _model(FinancialModelType.savingsRate, 0.10),
      ]);
      final below = _service.detect([
        _model(FinancialModelType.savingsRate, 0.05),
      ]);

      expect(equal, isEmpty);
      expect(below.single.deviationType, FinancialDeviationType.lowSavingsRate);
      expect(below.single.deviationAmount, closeTo(0.05, 0.0001));
    });

    test('detects high spending structure ratios', () {
      final deviations = _service.detect([
        _model(FinancialModelType.essentialRatio, 0.61),
        _model(FinancialModelType.flexibleRatio, 0.31),
        _model(FinancialModelType.lifestyleRatio, 0.21),
      ]);

      expect(
        deviations.map((deviation) => deviation.deviationType),
        containsAll([
          FinancialDeviationType.highEssentialExpenseRatio,
          FinancialDeviationType.highFlexibleExpenseRatio,
          FinancialDeviationType.highLifestyleExpenseRatio,
        ]),
      );
    });

    test('detects high recurring commitment load', () {
      final deviations = _service.detect([
        _model(FinancialModelType.incomeTotal, 2000),
        _model(FinancialModelType.recurringCommitments, 1200),
      ]);

      expect(
        deviations.single.deviationType,
        FinancialDeviationType.highRecurringCommitmentLoad,
      );
      expect(deviations.single.actualValue, 0.6);
      expect(deviations.single.expectedValue.thresholdValue, 0.5);
      expect(deviations.single.deviationAmount, closeTo(0.1, 0.0001));
      expect(
        deviations.single.evidence.sourceModelIds,
        containsAll([
          'financial.model.recurringCommitments',
          'financial.model.incomeTotal',
        ]),
      );
    });

    test('does not calculate recurring load with missing or zero income', () {
      final missingIncome = _service.detect([
        _model(FinancialModelType.recurringCommitments, 1200),
      ]);
      final zeroIncome = _service.detect([
        _model(FinancialModelType.incomeTotal, 0),
        _model(FinancialModelType.recurringCommitments, 1200),
      ]);

      expect(missingIncome, isEmpty);
      expect(zeroIncome, isEmpty);
    });

    test('detects weak data quality', () {
      final deviations = _service.detect([
        _model(FinancialModelType.dataQualityScore, 60),
      ]);

      expect(
        deviations.single.deviationType,
        FinancialDeviationType.weakDataQuality,
      );
      expect(deviations.single.expectedValue.thresholdValue, 70);
      expect(deviations.single.deviationAmount, 10);
    });

    test('skips unavailable unsupported and insufficient model results', () {
      final deviations = _service.detect([
        _model(
          FinancialModelType.netCashFlow,
          -500,
          status: FinancialModelStatus.unavailable,
        ),
        _model(
          FinancialModelType.expenseToIncomeRatio,
          0.90,
          status: FinancialModelStatus.insufficientData,
        ),
        _model(
          FinancialModelType.savingsRate,
          0,
          status: FinancialModelStatus.unsupported,
        ),
      ]);

      expect(deviations, isEmpty);
    });

    test('propagates confidence and limitations from source models', () {
      final deviations = _service.detect([
        _model(
          FinancialModelType.expenseToIncomeRatio,
          0.90,
          dataConfidence: FinancialModelConfidence.medium,
          modelConfidence: FinancialModelConfidence.high,
          limitations: const [FinancialModelLimitation.missingCategories],
        ),
      ]);

      final deviation = deviations.single;
      expect(deviation.confidence.name, 'medium');
      expect(
        deviation.limitations,
        contains(FinancialDeviationLimitation.sourceMissingCategories),
      );
    });

    test('includes explicit threshold metadata from catalog', () {
      final deviations = _service.detect([
        _model(FinancialModelType.dataQualityScore, 60),
      ]);
      final threshold = FinancialDeviationThresholdCatalog.thresholdFor(
        FinancialDeviationType.weakDataQuality,
      );

      expect(deviations.single.metadata.thresholdId, threshold.id);
      expect(deviations.single.metadata.calculatedAt, _calculatedAt);
      expect(deviations.single.severity, FinancialDeviationSeverity.low);
    });

    test('assigns high severity at high boundary', () {
      final deviations = _service.detect([
        _model(FinancialModelType.dataQualityScore, 35),
      ]);

      expect(deviations.single.deviationAmount, 35);
      expect(deviations.single.severity, FinancialDeviationSeverity.high);
    });

    test('assigns medium severity just below high boundary', () {
      final deviations = _service.detect([
        _model(FinancialModelType.dataQualityScore, 35.01),
      ]);

      expect(deviations.single.deviationAmount, closeTo(34.99, 0.0001));
      expect(deviations.single.severity, FinancialDeviationSeverity.medium);
    });

    test('assigns high severity just above high boundary', () {
      final deviations = _service.detect([
        _model(FinancialModelType.dataQualityScore, 34.99),
      ]);

      expect(deviations.single.deviationAmount, closeTo(35.01, 0.0001));
      expect(deviations.single.severity, FinancialDeviationSeverity.high);
    });

    test('assigns medium severity at medium boundary', () {
      final deviations = _service.detect([
        _model(FinancialModelType.dataQualityScore, 56),
      ]);

      expect(deviations.single.deviationAmount, 14);
      expect(deviations.single.severity, FinancialDeviationSeverity.medium);
    });

    test('assigns low severity just below medium boundary', () {
      final deviations = _service.detect([
        _model(FinancialModelType.dataQualityScore, 56.01),
      ]);

      expect(deviations.single.deviationAmount, closeTo(13.99, 0.0001));
      expect(deviations.single.severity, FinancialDeviationSeverity.low);
    });

    test('assigns medium severity just above medium boundary', () {
      final deviations = _service.detect([
        _model(FinancialModelType.dataQualityScore, 55.99),
      ]);

      expect(deviations.single.deviationAmount, closeTo(14.01, 0.0001));
      expect(deviations.single.severity, FinancialDeviationSeverity.medium);
    });

    test('threshold catalog has stable unique definitions', () {
      final ids = FinancialDeviationThresholdCatalog.thresholds
          .map((threshold) => threshold.id)
          .toSet();
      final types = FinancialDeviationThresholdCatalog.thresholds
          .map((threshold) => threshold.deviationType)
          .toSet();

      expect(
        ids,
        hasLength(FinancialDeviationThresholdCatalog.thresholds.length),
      );
      expect(
        types,
        hasLength(FinancialDeviationThresholdCatalog.thresholds.length),
      );
      expect(types, containsAll(FinancialDeviationType.values));
    });
  });
}

FinancialModelResult _model(
  FinancialModelType type,
  double value, {
  FinancialModelStatus status = FinancialModelStatus.calculated,
  FinancialModelConfidence dataConfidence = FinancialModelConfidence.high,
  FinancialModelConfidence modelConfidence = FinancialModelConfidence.high,
  List<FinancialModelLimitation> limitations = const [],
}) {
  return FinancialModelResult(
    modelId: 'financial.model.${type.name}',
    modelType: type,
    status: status,
    value: status == FinancialModelStatus.calculated ? value : null,
    unit: _unit(type),
    period: _period,
    currencyCode: _unit(type) == FinancialModelUnit.money ? 'CAD' : null,
    dataConfidence: dataConfidence,
    modelConfidence: modelConfidence,
    evidence: FinancialModelEvidence(
      factIds: ['fact:${type.name}'],
      dataGapSourceIds: const [],
    ),
    assumptions: const [],
    limitations: limitations,
    inputCoverage: limitations.isEmpty ? 1 : 0.7,
    metadata: FinancialModelMetadata(
      calculatedAt: _calculatedAt,
      engineVersion: 'test-models',
      snapshotVersion: 'test-snapshot',
    ),
    breakdown: const [],
  );
}

FinancialModelUnit _unit(FinancialModelType type) {
  return switch (type) {
    FinancialModelType.incomeTotal ||
    FinancialModelType.netCashFlow ||
    FinancialModelType.recurringCommitments => FinancialModelUnit.money,
    FinancialModelType.dataQualityScore => FinancialModelUnit.score,
    _ => FinancialModelUnit.ratio,
  };
}
