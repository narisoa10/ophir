import '../entities/financial_deviation.dart';
import '../entities/financial_model_result.dart';
import 'cash_flow_deviation_service.dart';
import 'data_quality_deviation_service.dart';
import 'ratio_deviation_service.dart';
import 'recurring_load_deviation_service.dart';

final class FinancialDeviationService {
  const FinancialDeviationService({
    this.cashFlowDeviationService = const CashFlowDeviationService(),
    this.ratioDeviationService = const RatioDeviationService(),
    this.recurringLoadDeviationService = const RecurringLoadDeviationService(),
    this.dataQualityDeviationService = const DataQualityDeviationService(),
  });

  final CashFlowDeviationService cashFlowDeviationService;
  final RatioDeviationService ratioDeviationService;
  final RecurringLoadDeviationService recurringLoadDeviationService;
  final DataQualityDeviationService dataQualityDeviationService;

  List<FinancialDeviation> detect(List<FinancialModelResult> modelResults) {
    return [
      ...cashFlowDeviationService.detect(modelResults),
      ...ratioDeviationService.detect(modelResults),
      ...recurringLoadDeviationService.detect(modelResults),
      ...dataQualityDeviationService.detect(modelResults),
    ];
  }
}
