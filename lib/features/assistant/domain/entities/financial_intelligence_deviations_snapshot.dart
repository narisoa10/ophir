import 'financial_intelligence_deviation.dart';
import 'financial_intelligence_deviation_type.dart';

final class FinancialIntelligenceDeviationsSnapshot {
  FinancialIntelligenceDeviationsSnapshot({
    required List<FinancialIntelligenceDeviation> deviations,
  }) : deviations = List.unmodifiable(deviations);

  final List<FinancialIntelligenceDeviation> deviations;

  List<FinancialIntelligenceDeviation> deviationsFor(
    FinancialIntelligenceDeviationType type,
  ) {
    return deviations
        .where((deviation) => deviation.type == type)
        .toList(growable: false);
  }

  bool hasDeviation(FinancialIntelligenceDeviationType type) {
    return deviations.any((deviation) => deviation.type == type);
  }
}
