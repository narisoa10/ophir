import 'financial_model_limitation.dart';
import 'financial_model_period.dart';
import 'financial_state_confidence.dart';
import 'financial_state_type.dart';

final class FinancialState {
  const FinancialState({
    required this.type,
    required this.confidence,
    required this.period,
    required this.currencyCode,
    required this.income,
    required this.expenses,
    required this.net,
    required this.evidenceModelIds,
    required this.limitations,
  });

  final FinancialStateType type;
  final FinancialStateConfidence confidence;
  final FinancialModelPeriod period;
  final String? currencyCode;
  final double income;
  final double expenses;
  final double net;
  final List<String> evidenceModelIds;
  final List<FinancialModelLimitation> limitations;
}
