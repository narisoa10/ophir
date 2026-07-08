import 'financial_fact.dart';
import 'financial_fact_data_gap.dart';

final class FinancialFactsSnapshot {
  const FinancialFactsSnapshot({required this.facts, required this.dataGaps});

  final List<FinancialFact> facts;
  final List<FinancialFactDataGap> dataGaps;
}
