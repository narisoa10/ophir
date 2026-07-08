import '../entities/financial_deviation.dart';
import '../entities/financial_deviation_type.dart';
import '../entities/financial_model_result.dart';
import '../entities/financial_model_status.dart';
import '../entities/financial_model_type.dart';
import 'financial_deviation_result_builder.dart';
import 'financial_deviation_threshold_catalog.dart';

final class DataQualityDeviationService {
  const DataQualityDeviationService({
    this.resultBuilder = const FinancialDeviationResultBuilder(),
  });

  final FinancialDeviationResultBuilder resultBuilder;

  List<FinancialDeviation> detect(List<FinancialModelResult> models) {
    final quality = _model(models, FinancialModelType.dataQualityScore);
    if (quality == null || quality.status != FinancialModelStatus.calculated) {
      return const [];
    }
    final actual = quality.value;
    if (actual == null) {
      return const [];
    }

    final threshold = FinancialDeviationThresholdCatalog.thresholdFor(
      FinancialDeviationType.weakDataQuality,
    );
    final expected = threshold.expectedValue.thresholdValue;
    if (actual >= expected) {
      return const [];
    }

    return [
      resultBuilder.calculated(
        type: FinancialDeviationType.weakDataQuality,
        actualValue: actual,
        deviationAmount: expected - actual,
        threshold: threshold,
        sourceModels: [quality],
      ),
    ];
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
