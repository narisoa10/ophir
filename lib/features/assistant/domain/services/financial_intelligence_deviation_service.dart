import '../entities/financial_deviation_severity.dart';
import '../entities/financial_intelligence_deviation.dart';
import '../entities/financial_intelligence_deviation_type.dart';
import '../entities/financial_intelligence_deviations_snapshot.dart';
import '../entities/financial_intelligence_diagnostics_read_model.dart';
import '../entities/financial_intelligence_model_type.dart';
import '../entities/financial_model_unit.dart';

final class FinancialIntelligenceDeviationService {
  const FinancialIntelligenceDeviationService();

  static const _ordinarySpendingPressureThreshold = 0.75;
  static const _mandatorySpendingPressureThreshold = 0.60;
  static const _flexibleSpendingPressureThreshold = 0.30;
  static const _discretionarySpendingPressureThreshold = 0.20;
  static const _mediumRatioDeviation = 0.05;
  static const _highRatioDeviation = 0.15;

  FinancialIntelligenceDeviationsSnapshot detect(
    FinancialIntelligenceDiagnosticsReadModel diagnostics,
  ) {
    final deviations = <FinancialIntelligenceDeviation>[
      ..._ratioPressure(
        diagnostics: diagnostics,
        type: FinancialIntelligenceDeviationType.ordinarySpendingPressure,
        modelType: FinancialIntelligenceModelType.ordinarySpendingRatio,
        threshold: _ordinarySpendingPressureThreshold,
      ),
      ..._ratioPressure(
        diagnostics: diagnostics,
        type: FinancialIntelligenceDeviationType.mandatorySpendingPressure,
        modelType: FinancialIntelligenceModelType.mandatoryRatio,
        threshold: _mandatorySpendingPressureThreshold,
      ),
      ..._ratioPressure(
        diagnostics: diagnostics,
        type: FinancialIntelligenceDeviationType.flexibleSpendingPressure,
        modelType: FinancialIntelligenceModelType.flexibleRatio,
        threshold: _flexibleSpendingPressureThreshold,
      ),
      ..._ratioPressure(
        diagnostics: diagnostics,
        type: FinancialIntelligenceDeviationType.discretionarySpendingPressure,
        modelType: FinancialIntelligenceModelType.discretionaryRatio,
        threshold: _discretionarySpendingPressureThreshold,
      ),
      ..._positiveSignal(
        diagnostics: diagnostics,
        type: FinancialIntelligenceDeviationType.assetBuildingSignal,
        modelType: FinancialIntelligenceModelType.assetBuildingTotal,
      ),
      ..._positiveSignal(
        diagnostics: diagnostics,
        type: FinancialIntelligenceDeviationType.debtReductionSignal,
        modelType: FinancialIntelligenceModelType.debtReductionTotal,
      ),
      ..._moneyWarning(
        diagnostics: diagnostics,
        type: FinancialIntelligenceDeviationType.contextRequiredWarning,
        modelType: FinancialIntelligenceModelType.contextRequiredTotal,
      ),
      ..._unresolvedWarning(diagnostics),
    ];

    return FinancialIntelligenceDeviationsSnapshot(deviations: deviations);
  }

  List<FinancialIntelligenceDeviation> _ratioPressure({
    required FinancialIntelligenceDiagnosticsReadModel diagnostics,
    required FinancialIntelligenceDeviationType type,
    required FinancialIntelligenceModelType modelType,
    required double threshold,
  }) {
    final actual = diagnostics.modelsSnapshot.valueFor(modelType);
    if (actual <= threshold) {
      return const [];
    }

    final deviationAmount = actual - threshold;
    return [
      FinancialIntelligenceDeviation(
        deviationId: 'financial.intelligence.deviation.${type.name}',
        type: type,
        actualValue: actual,
        expectedValue: threshold,
        deviationAmount: deviationAmount,
        unit: FinancialModelUnit.ratio,
        period: diagnostics.period,
        severity: _ratioSeverity(deviationAmount),
        sourceModelTypes: [modelType],
        isWarning: true,
        isDiagnosticsOnly: true,
      ),
    ];
  }

  List<FinancialIntelligenceDeviation> _positiveSignal({
    required FinancialIntelligenceDiagnosticsReadModel diagnostics,
    required FinancialIntelligenceDeviationType type,
    required FinancialIntelligenceModelType modelType,
  }) {
    final actual = diagnostics.modelsSnapshot.valueFor(modelType);
    if (actual <= 0) {
      return const [];
    }

    return [
      FinancialIntelligenceDeviation(
        deviationId: 'financial.intelligence.deviation.${type.name}',
        type: type,
        actualValue: actual,
        expectedValue: 0,
        deviationAmount: actual,
        unit: FinancialModelUnit.money,
        period: diagnostics.period,
        severity: FinancialDeviationSeverity.low,
        sourceModelTypes: [modelType],
        isWarning: false,
        isDiagnosticsOnly: true,
      ),
    ];
  }

  List<FinancialIntelligenceDeviation> _moneyWarning({
    required FinancialIntelligenceDiagnosticsReadModel diagnostics,
    required FinancialIntelligenceDeviationType type,
    required FinancialIntelligenceModelType modelType,
  }) {
    final actual = diagnostics.modelsSnapshot.valueFor(modelType);
    if (actual <= 0) {
      return const [];
    }

    return [
      FinancialIntelligenceDeviation(
        deviationId: 'financial.intelligence.deviation.${type.name}',
        type: type,
        actualValue: actual,
        expectedValue: 0,
        deviationAmount: actual,
        unit: FinancialModelUnit.money,
        period: diagnostics.period,
        severity: FinancialDeviationSeverity.medium,
        sourceModelTypes: [modelType],
        isWarning: true,
        isDiagnosticsOnly: true,
      ),
    ];
  }

  List<FinancialIntelligenceDeviation> _unresolvedWarning(
    FinancialIntelligenceDiagnosticsReadModel diagnostics,
  ) {
    final unresolvedCount = diagnostics.behaviorOutput.totals.unresolvedCount;
    if (unresolvedCount <= 0) {
      return const [];
    }

    return [
      FinancialIntelligenceDeviation(
        deviationId:
            'financial.intelligence.deviation.'
            '${FinancialIntelligenceDeviationType.unresolvedBehaviorWarning.name}',
        type: FinancialIntelligenceDeviationType.unresolvedBehaviorWarning,
        actualValue: unresolvedCount.toDouble(),
        expectedValue: 0,
        deviationAmount: unresolvedCount.toDouble(),
        unit: FinancialModelUnit.count,
        period: diagnostics.period,
        severity: FinancialDeviationSeverity.medium,
        sourceModelTypes: const [],
        isWarning: true,
        isDiagnosticsOnly: true,
      ),
    ];
  }

  FinancialDeviationSeverity _ratioSeverity(double deviationAmount) {
    if (deviationAmount >= _highRatioDeviation) {
      return FinancialDeviationSeverity.high;
    }
    if (deviationAmount >= _mediumRatioDeviation) {
      return FinancialDeviationSeverity.medium;
    }
    return FinancialDeviationSeverity.low;
  }
}
