import '../../../accounts/domain/entities/account.dart';
import '../../../categories/domain/entities/category.dart';
import '../../../operations/domain/entities/operation.dart';
import '../entities/assistant_dashboard_briefing.dart';
import '../entities/assistant_dashboard_radar.dart';
import '../entities/assistant_dashboard_radar_axis.dart';
import '../entities/assistant_dashboard_radar_axis_type.dart';
import '../entities/financial_explanation_fact_reference.dart';
import '../entities/financial_explanation_reference_index.dart';
import '../entities/financial_fact.dart';
import '../entities/financial_model_period.dart';
import '../entities/financial_model_result.dart';
import '../entities/financial_model_status.dart';
import '../entities/financial_model_type.dart';
import '../entities/financial_problem.dart';
import '../entities/financial_problem_severity.dart';
import 'financial_decision_options_service.dart';
import 'financial_deviation_service.dart';
import 'financial_explanation_service.dart';
import 'financial_facts_service.dart';
import 'financial_models_service.dart';
import 'financial_period_distribution_service.dart';
import 'financial_problem_detection_service.dart';
import 'financial_recommendation_service.dart';
import 'financial_state_service.dart';

final class AssistantDashboardBriefingService {
  const AssistantDashboardBriefingService({
    this.factsService = const FinancialFactsService(),
    this.modelsService = const FinancialModelsService(),
    this.deviationService = const FinancialDeviationService(),
    this.problemDetectionService = const FinancialProblemDetectionService(),
    this.decisionOptionsService = const FinancialDecisionOptionsService(),
    this.financialStateService = const FinancialStateService(),
    this.periodDistributionService = const FinancialPeriodDistributionService(),
  });

  final FinancialFactsService factsService;
  final FinancialModelsService modelsService;
  final FinancialDeviationService deviationService;
  final FinancialProblemDetectionService problemDetectionService;
  final FinancialDecisionOptionsService decisionOptionsService;
  final FinancialStateService financialStateService;
  final FinancialPeriodDistributionService periodDistributionService;

  AssistantDashboardBriefing build({
    required List<Account> accounts,
    required List<Operation> operations,
    required List<Category> categories,
    required DateTime now,
  }) {
    final period = _currentMonth(now);
    final factsSnapshot = factsService.buildSnapshot(
      accounts: accounts,
      operations: operations,
      categories: categories,
    );
    final modelResults = modelsService.calculateAll(
      snapshot: factsSnapshot,
      period: period,
      calculatedAt: now,
    );
    final deviations = deviationService.detect(modelResults);
    final problems = problemDetectionService.detect(deviations);
    final decisionOptions = decisionOptionsService.generate(problems);
    final recommendation = FinancialRecommendationService(
      generatedAt: now,
    ).recommend(decisionOptions);
    final financialState = financialStateService.evaluate(
      modelResults: modelResults,
    );
    final periodDistribution = periodDistributionService.build(modelResults);
    final explanation = recommendation == null
        ? null
        : FinancialExplanationService(generatedAt: now).explain(
            recommendation,
            FinancialExplanationReferenceIndex(
              options: decisionOptions,
              problems: problems,
              deviations: deviations,
              modelResults: modelResults,
              facts: factsSnapshot.facts.map(_factReference),
            ),
          );

    return AssistantDashboardBriefing(
      factsSnapshot: factsSnapshot,
      modelResults: modelResults,
      deviations: deviations,
      problems: problems,
      decisionOptions: decisionOptions,
      recommendation: recommendation,
      explanation: explanation,
      radar: _radar(modelResults),
      primaryProblem: _primaryProblem(problems),
      financialState: financialState,
      periodDistribution: periodDistribution,
    );
  }

  FinancialModelPeriod _currentMonth(DateTime now) {
    final start = DateTime(now.year, now.month);
    return FinancialModelPeriod(
      start: start,
      end: DateTime(now.year, now.month + 1),
    );
  }

  FinancialExplanationFactReference _factReference(FinancialFact fact) {
    return FinancialExplanationFactReference(
      factId: fact.id,
      factType: fact.type,
      confidence: fact.confidence,
      metadata: {
        if (fact.operationId != null) 'operationId': fact.operationId!,
        if (fact.categoryId != null) 'categoryId': fact.categoryId!,
        if (fact.accountId != null) 'accountId': fact.accountId!,
      },
    );
  }

  FinancialProblem? _primaryProblem(List<FinancialProblem> problems) {
    if (problems.isEmpty) {
      return null;
    }

    final sorted = [...problems]
      ..sort((left, right) {
        final severity = _severityRank(
          right.severity,
        ).compareTo(_severityRank(left.severity));
        if (severity != 0) {
          return severity;
        }
        return right.signals.length.compareTo(left.signals.length);
      });
    return sorted.first;
  }

  AssistantDashboardRadar _radar(List<FinancialModelResult> modelResults) {
    final byType = {
      for (final result in modelResults) result.modelType: result,
    };
    final axes = [
      _axis(
        type: AssistantDashboardRadarAxisType.cashFlow,
        result: byType[FinancialModelType.savingsRate],
        valueBuilder: (value) => ((value + 1) / 2).clamp(0, 1).toDouble(),
      ),
      _stabilityAxis(byType),
      _axis(
        type: AssistantDashboardRadarAxisType.spendingControl,
        result: byType[FinancialModelType.expenseToIncomeRatio],
        valueBuilder: (value) => (1 - value).clamp(0, 1).toDouble(),
      ),
      _axis(
        type: AssistantDashboardRadarAxisType.savingsPotential,
        result: byType[FinancialModelType.savingsRate],
        valueBuilder: (value) => value.clamp(0, 1).toDouble(),
      ),
    ];
    final availableAxes = axes.where((axis) => axis.value != null).length;
    final dataQuality = byType[FinancialModelType.dataQualityScore];
    final lowDataQuality =
        dataQuality?.status == FinancialModelStatus.calculated &&
        (dataQuality?.value ?? 0) < 60;

    return AssistantDashboardRadar(
      axes: axes,
      isLowConfidence: availableAxes < 3 || lowDataQuality,
      evidenceModelIds: axes
          .expand((axis) => axis.evidenceModelIds)
          .toSet()
          .toList(growable: false),
    );
  }

  AssistantDashboardRadarAxis _stabilityAxis(
    Map<FinancialModelType, FinancialModelResult> byType,
  ) {
    final fixed = byType[FinancialModelType.monthlyFixedCostEstimate];
    final income = byType[FinancialModelType.incomeTotal];
    if (!_isCalculated(fixed) || !_isCalculated(income) || income!.value == 0) {
      return const AssistantDashboardRadarAxis(
        type: AssistantDashboardRadarAxisType.stability,
        value: null,
        evidenceModelIds: [],
      );
    }

    final ratio = (fixed!.value ?? 0) / (income.value ?? 1);
    return AssistantDashboardRadarAxis(
      type: AssistantDashboardRadarAxisType.stability,
      value: (1 - ratio).clamp(0, 1).toDouble(),
      evidenceModelIds: [fixed.modelId, income.modelId],
    );
  }

  AssistantDashboardRadarAxis _axis({
    required AssistantDashboardRadarAxisType type,
    required FinancialModelResult? result,
    required double Function(double value) valueBuilder,
  }) {
    if (!_isCalculated(result)) {
      return AssistantDashboardRadarAxis(
        type: type,
        value: null,
        evidenceModelIds: const [],
      );
    }
    return AssistantDashboardRadarAxis(
      type: type,
      value: valueBuilder(result!.value!),
      evidenceModelIds: [result.modelId],
    );
  }

  bool _isCalculated(FinancialModelResult? result) {
    return result?.status == FinancialModelStatus.calculated &&
        result?.value != null;
  }

  int _severityRank(FinancialProblemSeverity severity) {
    return switch (severity) {
      FinancialProblemSeverity.low => 1,
      FinancialProblemSeverity.medium => 2,
      FinancialProblemSeverity.high => 3,
    };
  }
}
