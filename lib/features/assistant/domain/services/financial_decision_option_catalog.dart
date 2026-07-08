import '../entities/financial_decision_expected_model_change.dart';
import '../entities/financial_decision_option_condition.dart';
import '../entities/financial_decision_option_cost.dart';
import '../entities/financial_decision_option_cost_level.dart';
import '../entities/financial_decision_option_effect_horizon.dart';
import '../entities/financial_decision_option_limitation.dart';
import '../entities/financial_decision_option_risk.dart';
import '../entities/financial_decision_option_risk_level.dart';
import '../entities/financial_decision_option_rule.dart';
import '../entities/financial_decision_option_type.dart';
import '../entities/financial_decision_target.dart';
import '../entities/financial_decision_target_direction.dart';
import '../entities/financial_model_type.dart';
import '../entities/financial_model_unit.dart';
import '../entities/financial_problem_confidence.dart';
import '../entities/financial_problem_type.dart';

final class FinancialDecisionOptionCatalog {
  const FinancialDecisionOptionCatalog._();

  static const increaseIncome = FinancialDecisionOptionRule(
    ruleId: 'financial.decision.option.rule.increaseIncome',
    optionType: FinancialDecisionOptionType.increaseIncome,
    solvesProblemTypes: [
      FinancialProblemType.cashFlowDeficit,
      FinancialProblemType.weakSavingsCapacity,
      FinancialProblemType.essentialCostPressure,
      FinancialProblemType.fixedCommitmentPressure,
    ],
    mayWorsenProblemTypes: [],
    targets: [
      FinancialDecisionTarget(
        targetModelType: FinancialModelType.incomeTotal,
        desiredDirection: FinancialDecisionTargetDirection.increase,
        expectedImprovement: null,
        unit: FinancialModelUnit.money,
        confidence: FinancialProblemConfidence.low,
      ),
      FinancialDecisionTarget(
        targetModelType: FinancialModelType.netCashFlow,
        desiredDirection: FinancialDecisionTargetDirection.increase,
        expectedImprovement: null,
        unit: FinancialModelUnit.money,
        confidence: FinancialProblemConfidence.low,
      ),
    ],
    expectedModelChanges: [
      FinancialDecisionExpectedModelChange(
        modelType: FinancialModelType.incomeTotal,
        direction: FinancialDecisionTargetDirection.increase,
        expectedChange: null,
        unit: FinancialModelUnit.money,
        confidence: FinancialProblemConfidence.low,
      ),
      FinancialDecisionExpectedModelChange(
        modelType: FinancialModelType.netCashFlow,
        direction: FinancialDecisionTargetDirection.increase,
        expectedChange: null,
        unit: FinancialModelUnit.money,
        confidence: FinancialProblemConfidence.low,
      ),
      FinancialDecisionExpectedModelChange(
        modelType: FinancialModelType.savingsRate,
        direction: FinancialDecisionTargetDirection.increase,
        expectedChange: null,
        unit: FinancialModelUnit.percentage,
        confidence: FinancialProblemConfidence.low,
      ),
    ],
    cost: FinancialDecisionOptionCost(
      effort: FinancialDecisionOptionCostLevel.high,
      timeCost: FinancialDecisionOptionCostLevel.high,
      financialCost: FinancialDecisionOptionCostLevel.none,
    ),
    risk: FinancialDecisionOptionRisk(
      level: FinancialDecisionOptionRiskLevel.medium,
      mayWorsenProblemTypes: [],
    ),
    conditions: [
      FinancialDecisionOptionCondition(
        conditionId: 'condition.incomeActionAvailable',
        isRequired: true,
      ),
    ],
    limitations: [
      FinancialDecisionOptionLimitation(
        limitationId: 'limitation.noIncomeSourceModel',
      ),
    ],
    effectHorizon: FinancialDecisionOptionEffectHorizon.mediumTerm,
  );

  static const reduceDiscretionarySpending = FinancialDecisionOptionRule(
    ruleId: 'financial.decision.option.rule.reduceDiscretionarySpending',
    optionType: FinancialDecisionOptionType.reduceDiscretionarySpending,
    solvesProblemTypes: [
      FinancialProblemType.cashFlowDeficit,
      FinancialProblemType.expensePressure,
      FinancialProblemType.weakSavingsCapacity,
      FinancialProblemType.discretionarySpendingPressure,
    ],
    mayWorsenProblemTypes: [],
    targets: [
      FinancialDecisionTarget(
        targetModelType: FinancialModelType.flexibleRatio,
        desiredDirection: FinancialDecisionTargetDirection.decrease,
        expectedImprovement: null,
        unit: FinancialModelUnit.percentage,
        confidence: FinancialProblemConfidence.medium,
      ),
      FinancialDecisionTarget(
        targetModelType: FinancialModelType.lifestyleRatio,
        desiredDirection: FinancialDecisionTargetDirection.decrease,
        expectedImprovement: null,
        unit: FinancialModelUnit.percentage,
        confidence: FinancialProblemConfidence.medium,
      ),
    ],
    expectedModelChanges: [
      FinancialDecisionExpectedModelChange(
        modelType: FinancialModelType.expenseToIncomeRatio,
        direction: FinancialDecisionTargetDirection.decrease,
        expectedChange: null,
        unit: FinancialModelUnit.percentage,
        confidence: FinancialProblemConfidence.medium,
      ),
      FinancialDecisionExpectedModelChange(
        modelType: FinancialModelType.netCashFlow,
        direction: FinancialDecisionTargetDirection.increase,
        expectedChange: null,
        unit: FinancialModelUnit.money,
        confidence: FinancialProblemConfidence.medium,
      ),
      FinancialDecisionExpectedModelChange(
        modelType: FinancialModelType.savingsRate,
        direction: FinancialDecisionTargetDirection.increase,
        expectedChange: null,
        unit: FinancialModelUnit.percentage,
        confidence: FinancialProblemConfidence.medium,
      ),
    ],
    cost: FinancialDecisionOptionCost(
      effort: FinancialDecisionOptionCostLevel.medium,
      timeCost: FinancialDecisionOptionCostLevel.low,
      financialCost: FinancialDecisionOptionCostLevel.none,
    ),
    risk: FinancialDecisionOptionRisk(
      level: FinancialDecisionOptionRiskLevel.low,
      mayWorsenProblemTypes: [],
    ),
    conditions: [
      FinancialDecisionOptionCondition(
        conditionId: 'condition.discretionarySpendingEvidenceExists',
        isRequired: true,
      ),
    ],
    limitations: [],
    effectHorizon: FinancialDecisionOptionEffectHorizon.shortTerm,
  );

  static const reduceRecurringCommitments = FinancialDecisionOptionRule(
    ruleId: 'financial.decision.option.rule.reduceRecurringCommitments',
    optionType: FinancialDecisionOptionType.reduceRecurringCommitments,
    solvesProblemTypes: [
      FinancialProblemType.cashFlowDeficit,
      FinancialProblemType.expensePressure,
      FinancialProblemType.weakSavingsCapacity,
      FinancialProblemType.fixedCommitmentPressure,
    ],
    mayWorsenProblemTypes: [],
    targets: [
      FinancialDecisionTarget(
        targetModelType: FinancialModelType.recurringCommitments,
        desiredDirection: FinancialDecisionTargetDirection.decrease,
        expectedImprovement: null,
        unit: FinancialModelUnit.money,
        confidence: FinancialProblemConfidence.medium,
      ),
    ],
    expectedModelChanges: [
      FinancialDecisionExpectedModelChange(
        modelType: FinancialModelType.recurringCommitments,
        direction: FinancialDecisionTargetDirection.decrease,
        expectedChange: null,
        unit: FinancialModelUnit.money,
        confidence: FinancialProblemConfidence.medium,
      ),
      FinancialDecisionExpectedModelChange(
        modelType: FinancialModelType.netCashFlow,
        direction: FinancialDecisionTargetDirection.increase,
        expectedChange: null,
        unit: FinancialModelUnit.money,
        confidence: FinancialProblemConfidence.medium,
      ),
      FinancialDecisionExpectedModelChange(
        modelType: FinancialModelType.savingsRate,
        direction: FinancialDecisionTargetDirection.increase,
        expectedChange: null,
        unit: FinancialModelUnit.percentage,
        confidence: FinancialProblemConfidence.medium,
      ),
    ],
    cost: FinancialDecisionOptionCost(
      effort: FinancialDecisionOptionCostLevel.medium,
      timeCost: FinancialDecisionOptionCostLevel.medium,
      financialCost: FinancialDecisionOptionCostLevel.low,
    ),
    risk: FinancialDecisionOptionRisk(
      level: FinancialDecisionOptionRiskLevel.medium,
      mayWorsenProblemTypes: [],
    ),
    conditions: [
      FinancialDecisionOptionCondition(
        conditionId: 'condition.fixedCommitmentOrRecurringEvidenceExists',
        isRequired: true,
      ),
    ],
    limitations: [
      FinancialDecisionOptionLimitation(
        limitationId: 'limitation.noSubscriptionCancellationDetection',
      ),
    ],
    effectHorizon: FinancialDecisionOptionEffectHorizon.shortTerm,
  );

  static const optimizeEssentialExpenses = FinancialDecisionOptionRule(
    ruleId: 'financial.decision.option.rule.optimizeEssentialExpenses',
    optionType: FinancialDecisionOptionType.optimizeEssentialExpenses,
    solvesProblemTypes: [
      FinancialProblemType.cashFlowDeficit,
      FinancialProblemType.expensePressure,
      FinancialProblemType.essentialCostPressure,
    ],
    mayWorsenProblemTypes: [
      FinancialProblemType.cashFlowDeficit,
      FinancialProblemType.poorDataReliability,
    ],
    targets: [
      FinancialDecisionTarget(
        targetModelType: FinancialModelType.essentialRatio,
        desiredDirection: FinancialDecisionTargetDirection.decrease,
        expectedImprovement: null,
        unit: FinancialModelUnit.percentage,
        confidence: FinancialProblemConfidence.low,
      ),
    ],
    expectedModelChanges: [
      FinancialDecisionExpectedModelChange(
        modelType: FinancialModelType.essentialRatio,
        direction: FinancialDecisionTargetDirection.decrease,
        expectedChange: null,
        unit: FinancialModelUnit.percentage,
        confidence: FinancialProblemConfidence.low,
      ),
      FinancialDecisionExpectedModelChange(
        modelType: FinancialModelType.netCashFlow,
        direction: FinancialDecisionTargetDirection.increase,
        expectedChange: null,
        unit: FinancialModelUnit.money,
        confidence: FinancialProblemConfidence.low,
      ),
    ],
    cost: FinancialDecisionOptionCost(
      effort: FinancialDecisionOptionCostLevel.high,
      timeCost: FinancialDecisionOptionCostLevel.medium,
      financialCost: FinancialDecisionOptionCostLevel.low,
    ),
    risk: FinancialDecisionOptionRisk(
      level: FinancialDecisionOptionRiskLevel.high,
      mayWorsenProblemTypes: [
        FinancialProblemType.cashFlowDeficit,
        FinancialProblemType.poorDataReliability,
      ],
    ),
    conditions: [
      FinancialDecisionOptionCondition(
        conditionId: 'condition.essentialCostEvidenceExists',
        isRequired: true,
      ),
    ],
    limitations: [
      FinancialDecisionOptionLimitation(
        limitationId: 'limitation.essentialExpensesMayNotBeReducible',
      ),
    ],
    effectHorizon: FinancialDecisionOptionEffectHorizon.mediumTerm,
  );

  static const reviewExpenseStructure = FinancialDecisionOptionRule(
    ruleId: 'financial.decision.option.rule.reviewExpenseStructure',
    optionType: FinancialDecisionOptionType.reviewExpenseStructure,
    solvesProblemTypes: [
      FinancialProblemType.cashFlowDeficit,
      FinancialProblemType.expensePressure,
      FinancialProblemType.discretionarySpendingPressure,
      FinancialProblemType.essentialCostPressure,
    ],
    mayWorsenProblemTypes: [],
    targets: [
      FinancialDecisionTarget(
        targetModelType: FinancialModelType.expenseAnalyticsGroupTotals,
        desiredDirection: FinancialDecisionTargetDirection.clarify,
        expectedImprovement: null,
        unit: FinancialModelUnit.money,
        confidence: FinancialProblemConfidence.medium,
      ),
    ],
    expectedModelChanges: [
      FinancialDecisionExpectedModelChange(
        modelType: FinancialModelType.expenseAnalyticsGroupTotals,
        direction: FinancialDecisionTargetDirection.clarify,
        expectedChange: null,
        unit: FinancialModelUnit.money,
        confidence: FinancialProblemConfidence.medium,
      ),
    ],
    cost: FinancialDecisionOptionCost(
      effort: FinancialDecisionOptionCostLevel.low,
      timeCost: FinancialDecisionOptionCostLevel.low,
      financialCost: FinancialDecisionOptionCostLevel.none,
    ),
    risk: FinancialDecisionOptionRisk(
      level: FinancialDecisionOptionRiskLevel.none,
      mayWorsenProblemTypes: [],
    ),
    conditions: [],
    limitations: [],
    effectHorizon: FinancialDecisionOptionEffectHorizon.immediate,
  );

  static const reviewLargeExpense = FinancialDecisionOptionRule(
    ruleId: 'financial.decision.option.rule.reviewLargeExpense',
    optionType: FinancialDecisionOptionType.reviewLargeExpense,
    solvesProblemTypes: [
      FinancialProblemType.expensePressure,
      FinancialProblemType.discretionarySpendingPressure,
      FinancialProblemType.poorDataReliability,
    ],
    mayWorsenProblemTypes: [],
    targets: [
      FinancialDecisionTarget(
        targetModelType: FinancialModelType.expenseTotal,
        desiredDirection: FinancialDecisionTargetDirection.clarify,
        expectedImprovement: null,
        unit: FinancialModelUnit.money,
        confidence: FinancialProblemConfidence.low,
      ),
    ],
    expectedModelChanges: [
      FinancialDecisionExpectedModelChange(
        modelType: FinancialModelType.expenseTotal,
        direction: FinancialDecisionTargetDirection.clarify,
        expectedChange: null,
        unit: FinancialModelUnit.money,
        confidence: FinancialProblemConfidence.low,
      ),
    ],
    cost: FinancialDecisionOptionCost(
      effort: FinancialDecisionOptionCostLevel.low,
      timeCost: FinancialDecisionOptionCostLevel.low,
      financialCost: FinancialDecisionOptionCostLevel.none,
    ),
    risk: FinancialDecisionOptionRisk(
      level: FinancialDecisionOptionRiskLevel.none,
      mayWorsenProblemTypes: [],
    ),
    conditions: [
      FinancialDecisionOptionCondition(
        conditionId: 'condition.largeExpenseEvidenceExists',
        isRequired: false,
      ),
    ],
    limitations: [
      FinancialDecisionOptionLimitation(
        limitationId: 'limitation.noAnomalyDetectionLayer',
      ),
    ],
    effectHorizon: FinancialDecisionOptionEffectHorizon.immediate,
  );

  static const improveCategorization = FinancialDecisionOptionRule(
    ruleId: 'financial.decision.option.rule.improveCategorization',
    optionType: FinancialDecisionOptionType.improveCategorization,
    solvesProblemTypes: [FinancialProblemType.poorDataReliability],
    mayWorsenProblemTypes: [],
    targets: [
      FinancialDecisionTarget(
        targetModelType: FinancialModelType.dataQualityScore,
        desiredDirection: FinancialDecisionTargetDirection.increase,
        expectedImprovement: null,
        unit: FinancialModelUnit.none,
        confidence: FinancialProblemConfidence.high,
      ),
    ],
    expectedModelChanges: [
      FinancialDecisionExpectedModelChange(
        modelType: FinancialModelType.dataQualityScore,
        direction: FinancialDecisionTargetDirection.increase,
        expectedChange: null,
        unit: FinancialModelUnit.none,
        confidence: FinancialProblemConfidence.high,
      ),
      FinancialDecisionExpectedModelChange(
        modelType: FinancialModelType.unsupported,
        direction: FinancialDecisionTargetDirection.increase,
        expectedChange: null,
        unit: FinancialModelUnit.none,
        confidence: FinancialProblemConfidence.medium,
      ),
    ],
    cost: FinancialDecisionOptionCost(
      effort: FinancialDecisionOptionCostLevel.low,
      timeCost: FinancialDecisionOptionCostLevel.low,
      financialCost: FinancialDecisionOptionCostLevel.none,
    ),
    risk: FinancialDecisionOptionRisk(
      level: FinancialDecisionOptionRiskLevel.none,
      mayWorsenProblemTypes: [],
    ),
    conditions: [
      FinancialDecisionOptionCondition(
        conditionId: 'condition.uncategorizedOrWeakCategoryEvidenceExists',
        isRequired: true,
      ),
    ],
    limitations: [],
    effectHorizon: FinancialDecisionOptionEffectHorizon.immediate,
  );

  static const confirmRecurringOperations = FinancialDecisionOptionRule(
    ruleId: 'financial.decision.option.rule.confirmRecurringOperations',
    optionType: FinancialDecisionOptionType.confirmRecurringOperations,
    solvesProblemTypes: [
      FinancialProblemType.fixedCommitmentPressure,
      FinancialProblemType.poorDataReliability,
    ],
    mayWorsenProblemTypes: [],
    targets: [
      FinancialDecisionTarget(
        targetModelType: FinancialModelType.recurringCommitments,
        desiredDirection: FinancialDecisionTargetDirection.clarify,
        expectedImprovement: null,
        unit: FinancialModelUnit.money,
        confidence: FinancialProblemConfidence.medium,
      ),
    ],
    expectedModelChanges: [
      FinancialDecisionExpectedModelChange(
        modelType: FinancialModelType.recurringCommitments,
        direction: FinancialDecisionTargetDirection.clarify,
        expectedChange: null,
        unit: FinancialModelUnit.money,
        confidence: FinancialProblemConfidence.medium,
      ),
      FinancialDecisionExpectedModelChange(
        modelType: FinancialModelType.dataQualityScore,
        direction: FinancialDecisionTargetDirection.increase,
        expectedChange: null,
        unit: FinancialModelUnit.none,
        confidence: FinancialProblemConfidence.medium,
      ),
    ],
    cost: FinancialDecisionOptionCost(
      effort: FinancialDecisionOptionCostLevel.low,
      timeCost: FinancialDecisionOptionCostLevel.low,
      financialCost: FinancialDecisionOptionCostLevel.none,
    ),
    risk: FinancialDecisionOptionRisk(
      level: FinancialDecisionOptionRiskLevel.none,
      mayWorsenProblemTypes: [],
    ),
    conditions: [
      FinancialDecisionOptionCondition(
        conditionId: 'condition.recurringEvidenceOrUncertaintyExists',
        isRequired: true,
      ),
    ],
    limitations: [
      FinancialDecisionOptionLimitation(
        limitationId: 'limitation.noBankRecurringDetection',
      ),
    ],
    effectHorizon: FinancialDecisionOptionEffectHorizon.immediate,
  );

  static const collectMoreData = FinancialDecisionOptionRule(
    ruleId: 'financial.decision.option.rule.collectMoreData',
    optionType: FinancialDecisionOptionType.collectMoreData,
    solvesProblemTypes: [FinancialProblemType.poorDataReliability],
    mayWorsenProblemTypes: [],
    targets: [
      FinancialDecisionTarget(
        targetModelType: FinancialModelType.dataQualityScore,
        desiredDirection: FinancialDecisionTargetDirection.increase,
        expectedImprovement: null,
        unit: FinancialModelUnit.none,
        confidence: FinancialProblemConfidence.medium,
      ),
    ],
    expectedModelChanges: [
      FinancialDecisionExpectedModelChange(
        modelType: FinancialModelType.dataQualityScore,
        direction: FinancialDecisionTargetDirection.increase,
        expectedChange: null,
        unit: FinancialModelUnit.none,
        confidence: FinancialProblemConfidence.medium,
      ),
    ],
    cost: FinancialDecisionOptionCost(
      effort: FinancialDecisionOptionCostLevel.low,
      timeCost: FinancialDecisionOptionCostLevel.medium,
      financialCost: FinancialDecisionOptionCostLevel.none,
    ),
    risk: FinancialDecisionOptionRisk(
      level: FinancialDecisionOptionRiskLevel.low,
      mayWorsenProblemTypes: [],
    ),
    conditions: [
      FinancialDecisionOptionCondition(
        conditionId: 'condition.lowConfidenceOrPoorDataReliabilityExists',
        isRequired: true,
      ),
    ],
    limitations: [],
    effectHorizon: FinancialDecisionOptionEffectHorizon.shortTerm,
  );

  static const useExistingReserves = FinancialDecisionOptionRule(
    ruleId: 'financial.decision.option.rule.useExistingReserves',
    optionType: FinancialDecisionOptionType.useExistingReserves,
    solvesProblemTypes: [FinancialProblemType.cashFlowDeficit],
    mayWorsenProblemTypes: [FinancialProblemType.weakSavingsCapacity],
    targets: [
      FinancialDecisionTarget(
        targetModelType: FinancialModelType.simpleBurnRate,
        desiredDirection: FinancialDecisionTargetDirection.stabilize,
        expectedImprovement: null,
        unit: FinancialModelUnit.money,
        confidence: FinancialProblemConfidence.none,
      ),
    ],
    expectedModelChanges: [
      FinancialDecisionExpectedModelChange(
        modelType: FinancialModelType.simpleBurnRate,
        direction: FinancialDecisionTargetDirection.stabilize,
        expectedChange: null,
        unit: FinancialModelUnit.money,
        confidence: FinancialProblemConfidence.none,
      ),
    ],
    cost: FinancialDecisionOptionCost(
      effort: FinancialDecisionOptionCostLevel.low,
      timeCost: FinancialDecisionOptionCostLevel.low,
      financialCost: FinancialDecisionOptionCostLevel.high,
    ),
    risk: FinancialDecisionOptionRisk(
      level: FinancialDecisionOptionRiskLevel.high,
      mayWorsenProblemTypes: [FinancialProblemType.weakSavingsCapacity],
    ),
    conditions: [
      FinancialDecisionOptionCondition(
        conditionId: 'condition.reliableReserveOrLiquidityModelExists',
        isRequired: true,
      ),
    ],
    limitations: [
      FinancialDecisionOptionLimitation(
        limitationId: 'limitation.noReliableReserveLiquidityModel',
      ),
    ],
    effectHorizon: FinancialDecisionOptionEffectHorizon.immediate,
  );

  static const buildSavingsCapacity = FinancialDecisionOptionRule(
    ruleId: 'financial.decision.option.rule.buildSavingsCapacity',
    optionType: FinancialDecisionOptionType.buildSavingsCapacity,
    solvesProblemTypes: [FinancialProblemType.weakSavingsCapacity],
    mayWorsenProblemTypes: [FinancialProblemType.cashFlowDeficit],
    targets: [
      FinancialDecisionTarget(
        targetModelType: FinancialModelType.savingsRate,
        desiredDirection: FinancialDecisionTargetDirection.increase,
        expectedImprovement: null,
        unit: FinancialModelUnit.percentage,
        confidence: FinancialProblemConfidence.medium,
      ),
    ],
    expectedModelChanges: [
      FinancialDecisionExpectedModelChange(
        modelType: FinancialModelType.savingsRate,
        direction: FinancialDecisionTargetDirection.increase,
        expectedChange: null,
        unit: FinancialModelUnit.percentage,
        confidence: FinancialProblemConfidence.medium,
      ),
    ],
    cost: FinancialDecisionOptionCost(
      effort: FinancialDecisionOptionCostLevel.medium,
      timeCost: FinancialDecisionOptionCostLevel.medium,
      financialCost: FinancialDecisionOptionCostLevel.low,
    ),
    risk: FinancialDecisionOptionRisk(
      level: FinancialDecisionOptionRiskLevel.medium,
      mayWorsenProblemTypes: [FinancialProblemType.cashFlowDeficit],
    ),
    conditions: [
      FinancialDecisionOptionCondition(
        conditionId: 'condition.savingsCapacityCanBeImproved',
        isRequired: true,
      ),
    ],
    limitations: [
      FinancialDecisionOptionLimitation(
        limitationId: 'limitation.noGoalsLayer',
      ),
    ],
    effectHorizon: FinancialDecisionOptionEffectHorizon.mediumTerm,
  );

  static const reviseFinancialStrategy = FinancialDecisionOptionRule(
    ruleId: 'financial.decision.option.rule.reviseFinancialStrategy',
    optionType: FinancialDecisionOptionType.reviseFinancialStrategy,
    solvesProblemTypes: [
      FinancialProblemType.cashFlowDeficit,
      FinancialProblemType.weakSavingsCapacity,
      FinancialProblemType.essentialCostPressure,
      FinancialProblemType.fixedCommitmentPressure,
    ],
    mayWorsenProblemTypes: [],
    targets: [
      FinancialDecisionTarget(
        targetModelType: FinancialModelType.unsupported,
        desiredDirection: FinancialDecisionTargetDirection.stabilize,
        expectedImprovement: null,
        unit: FinancialModelUnit.none,
        confidence: FinancialProblemConfidence.none,
      ),
    ],
    expectedModelChanges: [
      FinancialDecisionExpectedModelChange(
        modelType: FinancialModelType.unsupported,
        direction: FinancialDecisionTargetDirection.stabilize,
        expectedChange: null,
        unit: FinancialModelUnit.none,
        confidence: FinancialProblemConfidence.none,
      ),
    ],
    cost: FinancialDecisionOptionCost(
      effort: FinancialDecisionOptionCostLevel.high,
      timeCost: FinancialDecisionOptionCostLevel.high,
      financialCost: FinancialDecisionOptionCostLevel.none,
    ),
    risk: FinancialDecisionOptionRisk(
      level: FinancialDecisionOptionRiskLevel.medium,
      mayWorsenProblemTypes: [],
    ),
    conditions: [
      FinancialDecisionOptionCondition(
        conditionId: 'condition.strategyLayerExists',
        isRequired: true,
      ),
    ],
    limitations: [
      FinancialDecisionOptionLimitation(
        limitationId: 'limitation.noStrategyLayer',
      ),
    ],
    effectHorizon: FinancialDecisionOptionEffectHorizon.longTerm,
  );

  static const restructureObligations = FinancialDecisionOptionRule(
    ruleId: 'financial.decision.option.rule.restructureObligations',
    optionType: FinancialDecisionOptionType.restructureObligations,
    solvesProblemTypes: [
      FinancialProblemType.cashFlowDeficit,
      FinancialProblemType.essentialCostPressure,
      FinancialProblemType.fixedCommitmentPressure,
    ],
    mayWorsenProblemTypes: [FinancialProblemType.poorDataReliability],
    targets: [
      FinancialDecisionTarget(
        targetModelType: FinancialModelType.recurringCommitments,
        desiredDirection: FinancialDecisionTargetDirection.decrease,
        expectedImprovement: null,
        unit: FinancialModelUnit.money,
        confidence: FinancialProblemConfidence.none,
      ),
    ],
    expectedModelChanges: [
      FinancialDecisionExpectedModelChange(
        modelType: FinancialModelType.recurringCommitments,
        direction: FinancialDecisionTargetDirection.decrease,
        expectedChange: null,
        unit: FinancialModelUnit.money,
        confidence: FinancialProblemConfidence.none,
      ),
    ],
    cost: FinancialDecisionOptionCost(
      effort: FinancialDecisionOptionCostLevel.high,
      timeCost: FinancialDecisionOptionCostLevel.high,
      financialCost: FinancialDecisionOptionCostLevel.medium,
    ),
    risk: FinancialDecisionOptionRisk(
      level: FinancialDecisionOptionRiskLevel.high,
      mayWorsenProblemTypes: [FinancialProblemType.poorDataReliability],
    ),
    conditions: [
      FinancialDecisionOptionCondition(
        conditionId: 'condition.debtOrObligationModelExists',
        isRequired: true,
      ),
    ],
    limitations: [
      FinancialDecisionOptionLimitation(limitationId: 'limitation.noDebtLayer'),
    ],
    effectHorizon: FinancialDecisionOptionEffectHorizon.mediumTerm,
  );

  static const adjustBudgetUnavailable = FinancialDecisionOptionRule(
    ruleId: 'financial.decision.option.rule.adjustBudgetUnavailable',
    optionType: FinancialDecisionOptionType.adjustBudgetUnavailable,
    solvesProblemTypes: [
      FinancialProblemType.expensePressure,
      FinancialProblemType.discretionarySpendingPressure,
    ],
    mayWorsenProblemTypes: [],
    targets: [
      FinancialDecisionTarget(
        targetModelType: FinancialModelType.unsupported,
        desiredDirection: FinancialDecisionTargetDirection.stabilize,
        expectedImprovement: null,
        unit: FinancialModelUnit.none,
        confidence: FinancialProblemConfidence.none,
      ),
    ],
    expectedModelChanges: [
      FinancialDecisionExpectedModelChange(
        modelType: FinancialModelType.unsupported,
        direction: FinancialDecisionTargetDirection.stabilize,
        expectedChange: null,
        unit: FinancialModelUnit.none,
        confidence: FinancialProblemConfidence.none,
      ),
    ],
    cost: FinancialDecisionOptionCost(
      effort: FinancialDecisionOptionCostLevel.medium,
      timeCost: FinancialDecisionOptionCostLevel.medium,
      financialCost: FinancialDecisionOptionCostLevel.none,
    ),
    risk: FinancialDecisionOptionRisk(
      level: FinancialDecisionOptionRiskLevel.medium,
      mayWorsenProblemTypes: [],
    ),
    conditions: [
      FinancialDecisionOptionCondition(
        conditionId: 'condition.budgetLayerExists',
        isRequired: true,
      ),
    ],
    limitations: [
      FinancialDecisionOptionLimitation(
        limitationId: 'limitation.noBudgetLayer',
      ),
    ],
    effectHorizon: FinancialDecisionOptionEffectHorizon.shortTerm,
  );

  static const deferOptionalSpending = FinancialDecisionOptionRule(
    ruleId: 'financial.decision.option.rule.deferOptionalSpending',
    optionType: FinancialDecisionOptionType.deferOptionalSpending,
    solvesProblemTypes: [
      FinancialProblemType.cashFlowDeficit,
      FinancialProblemType.weakSavingsCapacity,
      FinancialProblemType.discretionarySpendingPressure,
    ],
    mayWorsenProblemTypes: [],
    targets: [
      FinancialDecisionTarget(
        targetModelType: FinancialModelType.variableCostEstimate,
        desiredDirection: FinancialDecisionTargetDirection.decrease,
        expectedImprovement: null,
        unit: FinancialModelUnit.money,
        confidence: FinancialProblemConfidence.medium,
      ),
    ],
    expectedModelChanges: [
      FinancialDecisionExpectedModelChange(
        modelType: FinancialModelType.variableCostEstimate,
        direction: FinancialDecisionTargetDirection.decrease,
        expectedChange: null,
        unit: FinancialModelUnit.money,
        confidence: FinancialProblemConfidence.medium,
      ),
      FinancialDecisionExpectedModelChange(
        modelType: FinancialModelType.netCashFlow,
        direction: FinancialDecisionTargetDirection.increase,
        expectedChange: null,
        unit: FinancialModelUnit.money,
        confidence: FinancialProblemConfidence.medium,
      ),
    ],
    cost: FinancialDecisionOptionCost(
      effort: FinancialDecisionOptionCostLevel.low,
      timeCost: FinancialDecisionOptionCostLevel.low,
      financialCost: FinancialDecisionOptionCostLevel.none,
    ),
    risk: FinancialDecisionOptionRisk(
      level: FinancialDecisionOptionRiskLevel.low,
      mayWorsenProblemTypes: [],
    ),
    conditions: [
      FinancialDecisionOptionCondition(
        conditionId: 'condition.optionalSpendingEvidenceExists',
        isRequired: true,
      ),
    ],
    limitations: [],
    effectHorizon: FinancialDecisionOptionEffectHorizon.immediate,
  );

  static const doNothingAndMonitor = FinancialDecisionOptionRule(
    ruleId: 'financial.decision.option.rule.doNothingAndMonitor',
    optionType: FinancialDecisionOptionType.doNothingAndMonitor,
    solvesProblemTypes: [FinancialProblemType.poorDataReliability],
    mayWorsenProblemTypes: [
      FinancialProblemType.cashFlowDeficit,
      FinancialProblemType.expensePressure,
      FinancialProblemType.weakSavingsCapacity,
    ],
    targets: [
      FinancialDecisionTarget(
        targetModelType: FinancialModelType.dataQualityScore,
        desiredDirection: FinancialDecisionTargetDirection.clarify,
        expectedImprovement: null,
        unit: FinancialModelUnit.none,
        confidence: FinancialProblemConfidence.medium,
      ),
    ],
    expectedModelChanges: [
      FinancialDecisionExpectedModelChange(
        modelType: FinancialModelType.dataQualityScore,
        direction: FinancialDecisionTargetDirection.clarify,
        expectedChange: null,
        unit: FinancialModelUnit.none,
        confidence: FinancialProblemConfidence.medium,
      ),
    ],
    cost: FinancialDecisionOptionCost(
      effort: FinancialDecisionOptionCostLevel.none,
      timeCost: FinancialDecisionOptionCostLevel.medium,
      financialCost: FinancialDecisionOptionCostLevel.none,
    ),
    risk: FinancialDecisionOptionRisk(
      level: FinancialDecisionOptionRiskLevel.medium,
      mayWorsenProblemTypes: [
        FinancialProblemType.cashFlowDeficit,
        FinancialProblemType.expensePressure,
        FinancialProblemType.weakSavingsCapacity,
      ],
    ),
    conditions: [
      FinancialDecisionOptionCondition(
        conditionId: 'condition.lowConfidenceProblemExists',
        isRequired: true,
      ),
    ],
    limitations: [],
    effectHorizon: FinancialDecisionOptionEffectHorizon.shortTerm,
  );

  static const rules = <FinancialDecisionOptionRule>[
    increaseIncome,
    reduceDiscretionarySpending,
    reduceRecurringCommitments,
    optimizeEssentialExpenses,
    reviewExpenseStructure,
    reviewLargeExpense,
    improveCategorization,
    confirmRecurringOperations,
    collectMoreData,
    useExistingReserves,
    buildSavingsCapacity,
    reviseFinancialStrategy,
    restructureObligations,
    adjustBudgetUnavailable,
    deferOptionalSpending,
    doNothingAndMonitor,
  ];

  static FinancialDecisionOptionRule ruleFor(
    FinancialDecisionOptionType optionType,
  ) {
    return rules.singleWhere((rule) => rule.optionType == optionType);
  }
}
