import '../entities/financial_deviation.dart';
import '../entities/financial_deviation_type.dart';
import '../entities/financial_model_result.dart';
import '../entities/financial_model_status.dart';
import '../entities/financial_model_type.dart';
import 'financial_deviation_result_builder.dart';
import 'financial_deviation_threshold_catalog.dart';

final class RecurringLoadDeviationService {
  const RecurringLoadDeviationService({
    this.resultBuilder = const FinancialDeviationResultBuilder(),
  });

  final FinancialDeviationResultBuilder resultBuilder;

  List<FinancialDeviation> detect(List<FinancialModelResult> models) {
    final recurring =
        _model(models, FinancialModelType.recurringCommitments) ??
        _model(models, FinancialModelType.monthlyFixedCostEstimate);
    final income = _model(models, FinancialModelType.incomeTotal);
    if (recurring == null ||
        income == null ||
        recurring.status != FinancialModelStatus.calculated ||
        income.status != FinancialModelStatus.calculated) {
      return const [];
    }

    final recurringValue = recurring.value;
    final incomeValue = income.value;
    if (recurringValue == null || incomeValue == null || incomeValue == 0) {
      return const [];
    }

    final actual = recurringValue / incomeValue;
    final threshold = FinancialDeviationThresholdCatalog.thresholdFor(
      FinancialDeviationType.highRecurringCommitmentLoad,
    );
    final expected = threshold.expectedValue.thresholdValue;
    if (actual <= expected) {
      return const [];
    }

    return [
      resultBuilder.calculated(
        type: FinancialDeviationType.highRecurringCommitmentLoad,
        actualValue: actual,
        deviationAmount: actual - expected,
        threshold: threshold,
        sourceModels: [recurring, income],
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
