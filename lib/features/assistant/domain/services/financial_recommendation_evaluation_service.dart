import '../entities/financial_decision_option.dart';
import '../entities/financial_decision_option_applicability.dart';
import '../entities/financial_decision_option_cost_level.dart';
import '../entities/financial_decision_option_effect_horizon.dart';
import '../entities/financial_decision_option_risk_level.dart';
import '../entities/financial_decision_option_type.dart';
import '../entities/financial_recommendation_evaluation.dart';
import '../entities/financial_recommendation_evaluation_factor.dart';
import '../entities/financial_recommendation_factor_direction.dart';
import '../entities/financial_recommendation_factor_type.dart';
import '../entities/financial_recommendation_reversibility.dart';

final class FinancialRecommendationEvaluationService {
  const FinancialRecommendationEvaluationService();

  FinancialRecommendationEvaluation evaluate(FinancialDecisionOption option) {
    final expectedImpact = _expectedImpact(option);
    final cost = _cost(option);
    final risk = _risk(option);
    final applicability = _applicability(option);
    final confidence = _confidence(option);
    final urgency = _urgency(option);
    final reversibility = _reversibility(option.optionType);
    final horizon = _horizon(option.effectHorizon);
    final mayWorsenProblemCount = option.mayWorsenProblemTypes.length;

    return FinancialRecommendationEvaluation(
      optionId: option.optionId,
      optionType: option.optionType,
      expectedImpact: expectedImpact,
      cost: cost,
      risk: risk,
      applicability: applicability,
      confidence: confidence,
      urgency: urgency,
      reversibility: reversibility,
      horizon: horizon,
      mayWorsenProblemCount: mayWorsenProblemCount,
      factors: List.unmodifiable([
        FinancialRecommendationEvaluationFactor(
          factorType: FinancialRecommendationFactorType.expectedImpact,
          direction: FinancialRecommendationFactorDirection.positive,
          value: expectedImpact,
        ),
        FinancialRecommendationEvaluationFactor(
          factorType: FinancialRecommendationFactorType.cost,
          direction: FinancialRecommendationFactorDirection.negative,
          value: cost,
        ),
        FinancialRecommendationEvaluationFactor(
          factorType: FinancialRecommendationFactorType.risk,
          direction: FinancialRecommendationFactorDirection.negative,
          value: risk,
        ),
        FinancialRecommendationEvaluationFactor(
          factorType: FinancialRecommendationFactorType.applicability,
          direction: FinancialRecommendationFactorDirection.positive,
          value: applicability,
        ),
        FinancialRecommendationEvaluationFactor(
          factorType: FinancialRecommendationFactorType.confidence,
          direction: FinancialRecommendationFactorDirection.positive,
          value: confidence,
        ),
        FinancialRecommendationEvaluationFactor(
          factorType: FinancialRecommendationFactorType.urgency,
          direction: FinancialRecommendationFactorDirection.positive,
          value: urgency,
        ),
        FinancialRecommendationEvaluationFactor(
          factorType: FinancialRecommendationFactorType.reversibility,
          direction: FinancialRecommendationFactorDirection.positive,
          value: _reversibilityValue(reversibility),
        ),
        FinancialRecommendationEvaluationFactor(
          factorType: FinancialRecommendationFactorType.horizon,
          direction: FinancialRecommendationFactorDirection.positive,
          value: horizon,
        ),
        FinancialRecommendationEvaluationFactor(
          factorType: FinancialRecommendationFactorType.mayWorsenProblemTypes,
          direction: FinancialRecommendationFactorDirection.negative,
          value: mayWorsenProblemCount,
        ),
      ]),
    );
  }

  int _expectedImpact(FinancialDecisionOption option) {
    return option.expectedModelChanges.length +
        option.targets.length +
        (option.impact.isQuantitative ? 2 : 0);
  }

  int _cost(FinancialDecisionOption option) {
    return _costLevel(option.cost.effort) +
        _costLevel(option.cost.timeCost) +
        _costLevel(option.cost.financialCost);
  }

  int _risk(FinancialDecisionOption option) {
    return _riskLevel(option.risk.level) +
        option.risk.mayWorsenProblemTypes.length;
  }

  int _applicability(FinancialDecisionOption option) {
    return switch (option.applicability) {
      FinancialDecisionOptionApplicability.applicable => 2,
      FinancialDecisionOptionApplicability.conditional => 1,
      FinancialDecisionOptionApplicability.notApplicable ||
      FinancialDecisionOptionApplicability.futureUnavailable => 0,
    };
  }

  int _confidence(FinancialDecisionOption option) {
    final confidences = [
      ...option.targets.map((target) => target.confidence),
      ...option.expectedModelChanges.map((change) => change.confidence),
    ];
    if (confidences.isEmpty) {
      return 0;
    }
    final total = confidences
        .map((confidence) => _confidenceValue(confidence.name))
        .reduce((a, b) => a + b);
    return total ~/ confidences.length;
  }

  int _urgency(FinancialDecisionOption option) {
    final types = {
      ...option.solvesProblemTypes.map((type) => type.name),
      ...option.objectives.map((objective) => objective.sourceProblemType.name),
    };
    if (types.contains('cashFlowDeficit')) {
      return 4;
    }
    if (types.contains('expensePressure') ||
        types.contains('fixedCommitmentPressure')) {
      return 3;
    }
    if (types.contains('weakSavingsCapacity') ||
        types.contains('essentialCostPressure') ||
        types.contains('discretionarySpendingPressure')) {
      return 2;
    }
    if (types.contains('poorDataReliability')) {
      return 1;
    }
    return 0;
  }

  FinancialRecommendationReversibility _reversibility(
    FinancialDecisionOptionType type,
  ) {
    return switch (type) {
      FinancialDecisionOptionType.reviewExpenseStructure ||
      FinancialDecisionOptionType.reviewLargeExpense ||
      FinancialDecisionOptionType.improveCategorization ||
      FinancialDecisionOptionType.confirmRecurringOperations ||
      FinancialDecisionOptionType.collectMoreData ||
      FinancialDecisionOptionType.doNothingAndMonitor =>
        FinancialRecommendationReversibility.high,
      FinancialDecisionOptionType.reduceDiscretionarySpending ||
      FinancialDecisionOptionType.deferOptionalSpending ||
      FinancialDecisionOptionType.reduceRecurringCommitments ||
      FinancialDecisionOptionType.buildSavingsCapacity =>
        FinancialRecommendationReversibility.medium,
      FinancialDecisionOptionType.increaseIncome ||
      FinancialDecisionOptionType.optimizeEssentialExpenses ||
      FinancialDecisionOptionType.useExistingReserves ||
      FinancialDecisionOptionType.reviseFinancialStrategy ||
      FinancialDecisionOptionType.restructureObligations ||
      FinancialDecisionOptionType.adjustBudgetUnavailable =>
        FinancialRecommendationReversibility.low,
    };
  }

  int _horizon(FinancialDecisionOptionEffectHorizon horizon) {
    return switch (horizon) {
      FinancialDecisionOptionEffectHorizon.immediate => 4,
      FinancialDecisionOptionEffectHorizon.shortTerm => 3,
      FinancialDecisionOptionEffectHorizon.mediumTerm => 2,
      FinancialDecisionOptionEffectHorizon.longTerm => 1,
    };
  }

  int _costLevel(FinancialDecisionOptionCostLevel level) {
    return switch (level) {
      FinancialDecisionOptionCostLevel.none => 0,
      FinancialDecisionOptionCostLevel.low => 1,
      FinancialDecisionOptionCostLevel.medium => 2,
      FinancialDecisionOptionCostLevel.high => 3,
    };
  }

  int _riskLevel(FinancialDecisionOptionRiskLevel level) {
    return switch (level) {
      FinancialDecisionOptionRiskLevel.none => 0,
      FinancialDecisionOptionRiskLevel.low => 1,
      FinancialDecisionOptionRiskLevel.medium => 2,
      FinancialDecisionOptionRiskLevel.high => 3,
    };
  }

  int _confidenceValue(String confidence) {
    return switch (confidence) {
      'high' => 3,
      'medium' => 2,
      'low' => 1,
      'none' => 0,
      _ => 0,
    };
  }

  int _reversibilityValue(FinancialRecommendationReversibility reversibility) {
    return switch (reversibility) {
      FinancialRecommendationReversibility.high => 3,
      FinancialRecommendationReversibility.medium => 2,
      FinancialRecommendationReversibility.low => 1,
    };
  }
}
