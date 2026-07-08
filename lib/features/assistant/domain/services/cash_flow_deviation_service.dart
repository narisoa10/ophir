import '../entities/financial_deviation.dart';
import '../entities/financial_deviation_type.dart';
import '../entities/financial_model_result.dart';
import '../entities/financial_model_status.dart';
import '../entities/financial_model_type.dart';
import 'financial_deviation_result_builder.dart';
import 'financial_deviation_threshold_catalog.dart';

final class CashFlowDeviationService {
  const CashFlowDeviationService({
    this.resultBuilder = const FinancialDeviationResultBuilder(),
  });

  final FinancialDeviationResultBuilder resultBuilder;

  List<FinancialDeviation> detect(List<FinancialModelResult> models) {
    final netCashFlow = _model(models, FinancialModelType.netCashFlow);
    if (netCashFlow == null || !_isCalculated(netCashFlow)) {
      return const [];
    }
    final actual = netCashFlow.value;
    if (actual == null) {
      return const [];
    }

    final threshold = FinancialDeviationThresholdCatalog.thresholdFor(
      FinancialDeviationType.negativeNetCashFlow,
    );
    final expected = threshold.expectedValue.thresholdValue;
    if (actual >= expected) {
      return const [];
    }

    return [
      resultBuilder.calculated(
        type: FinancialDeviationType.negativeNetCashFlow,
        actualValue: actual,
        deviationAmount: expected - actual,
        threshold: threshold,
        sourceModels: [netCashFlow],
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

  bool _isCalculated(FinancialModelResult model) {
    return model.status == FinancialModelStatus.calculated;
  }
}
