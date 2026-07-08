import 'financial_fact_data_gap_type.dart';

final class FinancialFactDataGap {
  const FinancialFactDataGap({
    required this.type,
    required this.sourceId,
    required this.message,
  });

  final FinancialFactDataGapType type;
  final String sourceId;
  final String message;
}
