import '../entities/financial_deviation.dart';
import '../entities/financial_deviation_threshold.dart';
import '../entities/financial_deviation_type.dart';
import '../entities/financial_model_result.dart';
import '../entities/financial_model_status.dart';
import '../entities/financial_model_type.dart';
import 'financial_deviation_result_builder.dart';
import 'financial_deviation_threshold_catalog.dart';

final class RatioDeviationService {
  const RatioDeviationService({
    this.resultBuilder = const FinancialDeviationResultBuilder(),
  });

  final FinancialDeviationResultBuilder resultBuilder;

  List<FinancialDeviation> detect(List<FinancialModelResult> models) {
    return [
      ..._detect(
        models,
        FinancialModelType.expenseToIncomeRatio,
        FinancialDeviationType.highExpenseToIncomeRatio,
      ),
      ..._detect(
        models,
        FinancialModelType.savingsRate,
        FinancialDeviationType.lowSavingsRate,
      ),
      ..._detect(
        models,
        FinancialModelType.essentialRatio,
        FinancialDeviationType.highEssentialExpenseRatio,
      ),
      ..._detect(
        models,
        FinancialModelType.flexibleRatio,
        FinancialDeviationType.highFlexibleExpenseRatio,
      ),
      ..._detect(
        models,
        FinancialModelType.lifestyleRatio,
        FinancialDeviationType.highLifestyleExpenseRatio,
      ),
    ];
  }

  List<FinancialDeviation> _detect(
    List<FinancialModelResult> models,
    FinancialModelType modelType,
    FinancialDeviationType deviationType,
  ) {
    final model = _model(models, modelType);
    if (model == null || model.status != FinancialModelStatus.calculated) {
      return const [];
    }
    final actual = model.value;
    if (actual == null) {
      return const [];
    }

    final threshold = FinancialDeviationThresholdCatalog.thresholdFor(
      deviationType,
    );
    if (!_isDeviation(actual, threshold)) {
      return const [];
    }

    return [
      resultBuilder.calculated(
        type: deviationType,
        actualValue: actual,
        deviationAmount: _deviationAmount(actual, threshold),
        threshold: threshold,
        sourceModels: [model],
      ),
    ];
  }

  bool _isDeviation(double actual, FinancialDeviationThreshold threshold) {
    final expected = threshold.expectedValue.thresholdValue;
    return threshold.expectedValue.isUpperBound
        ? actual > expected
        : actual < expected;
  }

  double _deviationAmount(
    double actual,
    FinancialDeviationThreshold threshold,
  ) {
    final expected = threshold.expectedValue.thresholdValue;
    return threshold.expectedValue.isUpperBound
        ? actual - expected
        : expected - actual;
  }

  FinancialModelResult? _model(
    List<FinancialModelResult> models,
    FinancialModelType type,
  ) {
    for (final model in models) {
      if (model.modelType == type) {
        return model;
      }
    }
    return null;
  }
}
