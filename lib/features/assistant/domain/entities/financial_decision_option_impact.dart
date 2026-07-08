import 'financial_decision_option_effect_horizon.dart';

final class FinancialDecisionOptionImpact {
  const FinancialDecisionOptionImpact({
    required this.isQuantitative,
    required this.effectHorizon,
  });

  final bool isQuantitative;
  final FinancialDecisionOptionEffectHorizon effectHorizon;
}
