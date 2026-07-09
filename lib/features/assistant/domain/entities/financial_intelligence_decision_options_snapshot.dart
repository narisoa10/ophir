import 'financial_intelligence_decision_option.dart';
import 'financial_intelligence_decision_option_type.dart';

final class FinancialIntelligenceDecisionOptionsSnapshot {
  FinancialIntelligenceDecisionOptionsSnapshot({
    required List<FinancialIntelligenceDecisionOption> options,
  }) : options = List.unmodifiable(options);

  final List<FinancialIntelligenceDecisionOption> options;

  List<FinancialIntelligenceDecisionOption> optionsFor(
    FinancialIntelligenceDecisionOptionType type,
  ) {
    return options
        .where((option) => option.type == type)
        .toList(growable: false);
  }

  bool hasOption(FinancialIntelligenceDecisionOptionType type) {
    return options.any((option) => option.type == type);
  }
}
