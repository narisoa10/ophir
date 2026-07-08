import 'package:flutter/material.dart';

import '../../../../core/localization/generated/app_localizations.dart';
import '../../../../core/localization/l10n/dashboard_assistant_l10n.dart';
import '../../../../core/localization/l10n/dashboard_financial_state_l10n.dart';
import '../../../../core/localization/l10n/dashboard_l10n.dart';
import '../../../../core/theme_v1/app_colors.dart';
import '../../../assistant/domain/entities/assistant_dashboard_briefing.dart';
import '../../../assistant/domain/entities/assistant_dashboard_radar_axis.dart';
import '../../../assistant/domain/entities/assistant_dashboard_radar_axis_type.dart';
import '../../../assistant/domain/entities/financial_decision_option_effect_horizon.dart';
import '../../../assistant/domain/entities/financial_decision_option_type.dart';
import '../../../assistant/domain/entities/financial_fact.dart';
import '../../../assistant/domain/entities/financial_fact_type.dart';
import '../../../assistant/domain/entities/financial_model_result.dart';
import '../../../assistant/domain/entities/financial_model_status.dart';
import '../../../assistant/domain/entities/financial_model_type.dart';
import '../../../assistant/domain/entities/financial_problem.dart';
import '../../../assistant/domain/entities/financial_problem_type.dart';
import '../../../assistant/domain/entities/financial_recommendation_confidence.dart';
import '../../../assistant/domain/entities/financial_period_distribution_bucket.dart';
import '../../../assistant/domain/entities/financial_period_distribution_item.dart';
import '../../../assistant/domain/entities/financial_state_type.dart';
import '../../../categories/domain/enums/category_analytics_group.dart';
import '../../../operations/domain/enums/operation_recurrence.dart';
import '../../../operations/domain/enums/operation_type.dart';
import '../models/dashboard_presentation.dart';

final class DashboardPresentationAdapter {
  const DashboardPresentationAdapter();

  DashboardPresentation toPresentation({
    required AssistantDashboardBriefing briefing,
    required AppLocalizations l10n,
    required DateTime now,
    required String Function(DateTime date) formatDate,
    required String Function(double amount, String currencyCode) formatMoney,
  }) {
    final currencyCode = _currencyCode(briefing);
    final modelByType = {
      for (final model in briefing.modelResults) model.modelType: model,
    };
    final todayFacts = _todayFacts(briefing.factsSnapshot.facts, now);
    final income = _modelValue(modelByType, FinancialModelType.incomeTotal);
    final expenses = _modelValue(modelByType, FinancialModelType.expenseTotal);
    final net = _modelValue(modelByType, FinancialModelType.netCashFlow);
    final summary = _assistantSummary(briefing, l10n, formatDate, formatMoney);

    return DashboardPresentation(
      assistantSummary: summary,
      today: DashboardTodayPresentation(
        net: formatMoney(_net(todayFacts), currencyCode),
        income: formatMoney(
          _sum(todayFacts, OperationType.income),
          currencyCode,
        ),
        expenses: formatMoney(
          _sum(todayFacts, OperationType.expense),
          currencyCode,
        ),
        operationCount: l10n.dashboardOperationsCount(todayFacts.length),
        summary: todayFacts.isEmpty
            ? l10n.dashboardTodayEmpty
            : _net(todayFacts) >= 0
            ? l10n.dashboardTodayPositive
            : l10n.dashboardTodayNegative,
      ),
      recordedBalance: DashboardRecordedBalancePresentation(
        amount: formatMoney(
          _recordedBalance(briefing.factsSnapshot.facts),
          currencyCode,
        ),
        description: l10n.dashboardRecordedBalanceDescription,
      ),
      cashFlow: DashboardCashFlowPresentation(
        income: formatMoney(income ?? 0, currencyCode),
        expenses: formatMoney(expenses ?? 0, currencyCode),
        net: formatMoney(net ?? 0, currencyCode),
        summary: _cashFlowSummary(modelByType, l10n),
        groups: _expenseGroups(modelByType, l10n, formatMoney, currencyCode),
      ),
      insights: [summary.why, summary.whatNext],
      upcoming: _upcoming(
        briefing.factsSnapshot.facts,
        now,
        formatDate,
        formatMoney,
        l10n,
      ),
      actions: [summary.recommendedAction],
    );
  }

  DashboardAssistantSummaryPresentation _assistantSummary(
    AssistantDashboardBriefing briefing,
    AppLocalizations l10n,
    String Function(DateTime date) formatDate,
    String Function(double amount, String currencyCode) formatMoney,
  ) {
    return DashboardAssistantSummaryPresentation(
      stateTitle: l10n.dashboardAssistantStateTitle,
      stateDescription: briefing.primaryProblem == null
          ? l10n.dashboardAssistantStateStable
          : l10n.dashboardAssistantStateWatch,
      financialState: _financialStatePresentation(
        briefing,
        l10n,
        formatDate,
        formatMoney,
      ),
      radar: DashboardRadarPresentation(
        axes: briefing.radar.axes
            .map((axis) => _radarAxis(axis, l10n))
            .toList(),
        isLowConfidence: briefing.radar.isLowConfidence,
        caption: briefing.radar.isLowConfidence
            ? l10n.dashboardRadarLowConfidence
            : l10n.dashboardRadarEvidenceReady,
      ),
      why: _why(briefing, l10n),
      whatNext: _whatNext(briefing, l10n),
      recommendedAction: _recommendedAction(briefing, l10n),
      detailLinks: [
        DashboardDetailLinkPresentation(
          title: l10n.dashboardCashFlowTitle,
          routeKey: 'cashFlow',
        ),
        DashboardDetailLinkPresentation(
          title: l10n.dashboardInsightsTitle,
          routeKey: 'insights',
        ),
        DashboardDetailLinkPresentation(
          title: l10n.dashboardActionsTitle,
          routeKey: 'actions',
        ),
      ],
    );
  }

  DashboardFinancialStatePresentation _financialStatePresentation(
    AssistantDashboardBriefing briefing,
    AppLocalizations l10n,
    String Function(DateTime date) formatDate,
    String Function(double amount, String currencyCode) formatMoney,
  ) {
    final state = briefing.financialState;
    final distribution = briefing.periodDistribution;
    final currencyCode =
        distribution.currencyCode ??
        state.currencyCode ??
        _currencyCode(briefing);
    final periodEnd = state.period.end.subtract(const Duration(days: 1));

    return DashboardFinancialStatePresentation(
      title: l10n.dashboardPeriodDistributionTitle,
      subtitle: l10n.dashboardPeriodDistributionSubtitle,
      items: distribution.items
          .map(
            (item) => _allocationItem(
              item,
              l10n,
              formatMoney,
              distribution.currencyCode ?? currencyCode,
            ),
          )
          .toList(growable: false),
      stateLabel: _stateTitle(state.type, l10n),
      stateDescription: _stateDescription(state.type, l10n),
      stateIcon: _stateIcon(state.type),
      stateColor: _stateColor(state.type),
      stateBackgroundColor: _stateBackgroundColor(state.type),
      incomeTotalLabel: l10n.dashboardIncomeLabel,
      incomeTotalAmount: formatMoney(distribution.incomeTotal, currencyCode),
      expenseTotalLabel: l10n.dashboardExpensesLabel,
      expenseTotalAmount: formatMoney(distribution.expenseTotal, currencyCode),
      netCashFlowLabel: l10n.dashboardCashLeftLabel,
      netCashFlowAmount: formatMoney(distribution.netCashFlow, currencyCode),
      periodLabel: l10n.dashboardPeriodLabel(
        formatDate(state.period.start),
        formatDate(periodEnd),
      ),
      detailButtonLabel: l10n.dashboardDetailButton,
      detail: _financialStateDetailPresentation(
        briefing,
        l10n,
        formatMoney,
        currencyCode,
      ),
    );
  }

  DashboardFinancialStateDetailPresentation _financialStateDetailPresentation(
    AssistantDashboardBriefing briefing,
    AppLocalizations l10n,
    String Function(double amount, String currencyCode) formatMoney,
    String currencyCode,
  ) {
    final state = briefing.financialState;
    final recommendation = briefing.recommendation;
    final explanation = briefing.explanation;

    return DashboardFinancialStateDetailPresentation(
      title: l10n.dashboardFinancialStateDetailTitle,
      currentStateTitle: _stateTitle(state.type, l10n),
      currentStateDescription: _stateDescription(state.type, l10n),
      whyTitle: l10n.dashboardFinancialStateDetailWhyTitle,
      whyDescription: briefing.primaryProblem == null
          ? l10n.dashboardNoMainProblemDescription
          : l10n.dashboardProblemTitle(
              _problemLabel(briefing.primaryProblem!, l10n),
            ),
      problemsTitle: l10n.dashboardFinancialStateDetailProblemsTitle,
      problems: briefing.problems.isEmpty
          ? [l10n.dashboardFinancialStateDetailNoProblems]
          : briefing.problems
                .map(
                  (problem) => l10n.dashboardProblemDetail(
                    _problemLabel(problem, l10n),
                    problem.signals.length,
                  ),
                )
                .toList(growable: false),
      influenceTitle: l10n.dashboardFinancialStateDetailInfluenceTitle,
      buckets: briefing.periodDistribution.items
          .map(
            (item) => _allocationItem(
              item,
              l10n,
              formatMoney,
              item.bucket == FinancialPeriodDistributionBucket.savings
                  ? (briefing.periodDistribution.currencyCode ?? currencyCode)
                  : currencyCode,
            ),
          )
          .toList(growable: false),
      recommendationTitle:
          l10n.dashboardFinancialStateDetailRecommendationTitle,
      recommendationDescription: recommendation == null
          ? l10n.dashboardNextNoRecommendation
          : l10n.dashboardRecommendationDetail(
              _optionLabel(recommendation.selectedOptionType, l10n),
              _horizonLabel(recommendation.selectedOption.effectHorizon, l10n),
              _confidenceLabel(recommendation.confidence, l10n),
            ),
      evidenceTitle: l10n.dashboardFinancialStateDetailEvidenceTitle,
      evidence: [
        l10n.dashboardStateEvidenceModels(state.evidenceModelIds.length),
        if (briefing.primaryProblem != null)
          l10n.dashboardProblemEvidenceModels(
            briefing.primaryProblem!.evidence.sourceModelIds.length,
          ),
        if (explanation != null)
          l10n.dashboardExplanationEvidence(
            explanation.steps.length,
            explanation.graph.nodes.length,
          )
        else
          l10n.dashboardExplanationEvidenceUnavailable,
      ],
    );
  }

  DashboardPeriodDistributionItemPresentation _allocationItem(
    FinancialPeriodDistributionItem item,
    AppLocalizations l10n,
    String Function(double amount, String currencyCode) formatMoney,
    String currencyCode,
  ) {
    return DashboardPeriodDistributionItemPresentation(
      label: _allocationLabel(item.bucket, l10n),
      amount: formatMoney(item.amount, currencyCode),
      percent: _formatPercent(item.percent, l10n),
      progress: item.percent.clamp(0, 1).toDouble(),
      icon: _allocationIcon(item.bucket),
      color: _allocationColor(item.bucket),
      backgroundColor: _allocationBackgroundColor(item.bucket),
      hasDetail: false,
    );
  }

  DashboardRadarAxisPresentation _radarAxis(
    AssistantDashboardRadarAxis axis,
    AppLocalizations l10n,
  ) {
    return DashboardRadarAxisPresentation(
      label: switch (axis.type) {
        AssistantDashboardRadarAxisType.cashFlow => l10n.dashboardRadarCashFlow,
        AssistantDashboardRadarAxisType.stability =>
          l10n.dashboardRadarStability,
        AssistantDashboardRadarAxisType.spendingControl =>
          l10n.dashboardRadarSpendingControl,
        AssistantDashboardRadarAxisType.savingsPotential =>
          l10n.dashboardRadarSavingsPotential,
      },
      value: axis.value ?? 0,
      isAvailable: axis.value != null,
    );
  }

  DashboardMessagePresentation _why(
    AssistantDashboardBriefing briefing,
    AppLocalizations l10n,
  ) {
    final problem = briefing.primaryProblem;
    if (problem == null) {
      return DashboardMessagePresentation(
        title: l10n.dashboardNoMainProblemTitle,
        description: l10n.dashboardNoMainProblemDescription,
        icon: Icons.check_circle_outline,
        color: AppColors.success,
        backgroundColor: AppColors.surfaceGreen,
      );
    }

    return DashboardMessagePresentation(
      title: l10n.dashboardProblemTitle(_problemLabel(problem, l10n)),
      description: l10n.dashboardProblemEvidence(
        problem.signals.length,
        briefing.deviations.length,
      ),
      icon: Icons.manage_search,
      color: _problemColor(problem),
      backgroundColor: _problemBackground(problem),
    );
  }

  DashboardMessagePresentation _whatNext(
    AssistantDashboardBriefing briefing,
    AppLocalizations l10n,
  ) {
    final recommendation = briefing.recommendation;
    if (recommendation == null) {
      return DashboardMessagePresentation(
        title: l10n.dashboardWhatNextTitle,
        description: l10n.dashboardNextNoRecommendation,
        icon: Icons.timeline,
        color: AppColors.chartBlue,
        backgroundColor: AppColors.surfaceBlue,
      );
    }

    return DashboardMessagePresentation(
      title: l10n.dashboardWhatNextTitle,
      description: l10n.dashboardNextFromRecommendation(
        _horizonLabel(recommendation.selectedOption.effectHorizon, l10n),
      ),
      icon: Icons.trending_up,
      color: AppColors.chartBlue,
      backgroundColor: AppColors.surfaceBlue,
    );
  }

  DashboardMessagePresentation _recommendedAction(
    AssistantDashboardBriefing briefing,
    AppLocalizations l10n,
  ) {
    final recommendation = briefing.recommendation;
    if (recommendation == null) {
      return DashboardMessagePresentation(
        title: l10n.dashboardRecommendationEmptyTitle,
        description: l10n.dashboardRecommendationEmptyDescription,
        icon: Icons.visibility_outlined,
        color: AppColors.iconSecondary,
        backgroundColor: AppColors.background,
      );
    }

    return DashboardMessagePresentation(
      title: _optionLabel(recommendation.selectedOptionType, l10n),
      description: l10n.dashboardRecommendationConfidence(
        _confidenceLabel(recommendation.confidence, l10n),
      ),
      icon: Icons.checklist,
      color: AppColors.primary,
      backgroundColor: AppColors.primaryLight,
    );
  }

  String _cashFlowSummary(
    Map<FinancialModelType, FinancialModelResult> modelByType,
    AppLocalizations l10n,
  ) {
    final net = _modelValue(modelByType, FinancialModelType.netCashFlow);
    if (net == null) {
      return l10n.dashboardCashFlowEmpty;
    }
    return net >= 0
        ? l10n.dashboardCashFlowPositive
        : l10n.dashboardCashFlowNegative;
  }

  List<DashboardMetricPresentation> _expenseGroups(
    Map<FinancialModelType, FinancialModelResult> modelByType,
    AppLocalizations l10n,
    String Function(double amount, String currencyCode) formatMoney,
    String currencyCode,
  ) {
    final groups = modelByType[FinancialModelType.expenseAnalyticsGroupTotals];
    if (groups?.status != FinancialModelStatus.calculated) {
      return const [];
    }

    return groups!.breakdown
        .map((model) {
          final group = _groupFromAssumption(model.assumptions);
          return DashboardMetricPresentation(
            label: _analyticsGroupLabel(group, l10n),
            value: formatMoney(
              model.value ?? 0,
              model.currencyCode ?? currencyCode,
            ),
            color: _analyticsGroupColor(group),
          );
        })
        .toList(growable: false);
  }

  List<DashboardUpcomingPresentation> _upcoming(
    List<FinancialFact> facts,
    DateTime now,
    String Function(DateTime date) formatDate,
    String Function(double amount, String currencyCode) formatMoney,
    AppLocalizations l10n,
  ) {
    final byOperation = {
      for (final fact in facts)
        if (fact.type == FinancialFactType.expenseOperation ||
            fact.type == FinancialFactType.incomeOperation)
          fact.operationId: fact,
    };
    final upcoming = facts
        .where((fact) => fact.type == FinancialFactType.recurringOperation)
        .map((fact) {
          final operation = byOperation[fact.operationId];
          final nextDate = _nextOccurrence(fact, now);
          if (operation == null || nextDate == null) {
            return null;
          }
          return (
            nextDate: nextDate,
            presentation: DashboardUpcomingPresentation(
              title: l10n.dashboardUpcomingRecurringDescription,
              amount: formatMoney(
                operation.operationType == OperationType.expense
                    ? -(operation.amount ?? 0)
                    : operation.amount ?? 0,
                operation.currencyCode ?? _currencyCodeFromFacts(facts),
              ),
              date: formatDate(nextDate),
              description: l10n.dashboardUpcomingRecurringDescription,
            ),
          );
        })
        .whereType<
          ({DateTime nextDate, DashboardUpcomingPresentation presentation})
        >()
        .toList();

    upcoming.sort((left, right) => left.nextDate.compareTo(right.nextDate));
    return upcoming
        .take(3)
        .map((entry) => entry.presentation)
        .toList(growable: false);
  }

  DateTime? _nextOccurrence(FinancialFact fact, DateTime now) {
    if (fact.recurrence == null || fact.occurredAt == null) {
      return null;
    }

    var candidate = fact.occurredAt!;
    var guard = 0;
    while (!candidate.isAfter(now) && guard < 400) {
      candidate = switch (fact.recurrence!) {
        OperationRecurrence.none => candidate,
        OperationRecurrence.daily => candidate.add(const Duration(days: 1)),
        OperationRecurrence.weekly => candidate.add(const Duration(days: 7)),
        OperationRecurrence.biweekly => candidate.add(const Duration(days: 14)),
        OperationRecurrence.monthly => _addMonths(candidate, 1),
        OperationRecurrence.yearly => _addMonths(candidate, 12),
      };
      guard++;
    }
    return candidate.isAfter(now) ? candidate : null;
  }

  DateTime _addMonths(DateTime date, int months) {
    final normalized = DateTime(date.year, date.month + months);
    final lastDay = DateTime(normalized.year, normalized.month + 1, 0).day;
    final day = date.day > lastDay ? lastDay : date.day;
    return DateTime(normalized.year, normalized.month, day);
  }

  List<FinancialFact> _todayFacts(List<FinancialFact> facts, DateTime now) {
    return facts
        .where((fact) {
          final occurredAt = fact.occurredAt;
          return occurredAt != null &&
              occurredAt.year == now.year &&
              occurredAt.month == now.month &&
              occurredAt.day == now.day &&
              (fact.type == FinancialFactType.expenseOperation ||
                  fact.type == FinancialFactType.incomeOperation);
        })
        .toList(growable: false);
  }

  double _recordedBalance(List<FinancialFact> facts) {
    return facts.fold<double>(0, (sum, fact) {
      final amount = fact.amount ?? 0;
      return switch (fact.type) {
        FinancialFactType.accountBalanceSeed => sum + amount,
        FinancialFactType.incomeOperation => sum + amount,
        FinancialFactType.expenseOperation => sum - amount,
        _ => sum,
      };
    });
  }

  double _net(List<FinancialFact> facts) {
    return _sum(facts, OperationType.income) -
        _sum(facts, OperationType.expense);
  }

  double _sum(List<FinancialFact> facts, OperationType type) {
    return facts
        .where((fact) => fact.operationType == type)
        .fold<double>(0, (sum, fact) => sum + (fact.amount ?? 0));
  }

  double? _modelValue(
    Map<FinancialModelType, FinancialModelResult> modelByType,
    FinancialModelType type,
  ) {
    final model = modelByType[type];
    if (model?.status != FinancialModelStatus.calculated) {
      return null;
    }
    return model?.value;
  }

  String _currencyCode(AssistantDashboardBriefing briefing) {
    for (final model in briefing.modelResults) {
      if (model.currencyCode != null) {
        return model.currencyCode!;
      }
    }
    return _currencyCodeFromFacts(briefing.factsSnapshot.facts);
  }

  String _currencyCodeFromFacts(List<FinancialFact> facts) {
    for (final fact in facts) {
      if (fact.currencyCode != null) {
        return fact.currencyCode!;
      }
    }
    return 'CAD';
  }

  CategoryAnalyticsGroup _groupFromAssumption(List<String> assumptions) {
    String? value;
    for (final assumption in assumptions) {
      if (assumption.startsWith('analyticsGroup:')) {
        value = assumption.substring('analyticsGroup:'.length);
        break;
      }
    }
    return CategoryAnalyticsGroup.values.firstWhere(
      (group) => group.name == value,
      orElse: () => CategoryAnalyticsGroup.flexibleExpenses,
    );
  }

  String _problemLabel(FinancialProblem problem, AppLocalizations l10n) {
    return switch (problem.problemType) {
      FinancialProblemType.cashFlowDeficit => l10n.dashboardCashFlowTitle,
      FinancialProblemType.expensePressure => l10n.dashboardExpensesLabel,
      FinancialProblemType.weakSavingsCapacity =>
        l10n.dashboardRadarSavingsPotential,
      FinancialProblemType.discretionarySpendingPressure =>
        l10n.dashboardRadarSpendingControl,
      FinancialProblemType.essentialCostPressure =>
        l10n.dashboardAnalyticsEssential,
      FinancialProblemType.fixedCommitmentPressure =>
        l10n.dashboardRadarStability,
      FinancialProblemType.poorDataReliability =>
        l10n.dashboardRadarLowConfidence,
    };
  }

  String _optionLabel(
    FinancialDecisionOptionType optionType,
    AppLocalizations l10n,
  ) {
    return switch (optionType) {
      FinancialDecisionOptionType.increaseIncome => l10n.dashboardIncomeLabel,
      FinancialDecisionOptionType.reduceDiscretionarySpending =>
        l10n.dashboardActionCheckCashFlowTitle,
      FinancialDecisionOptionType.reduceRecurringCommitments =>
        l10n.dashboardActionAddRecurringTitle,
      FinancialDecisionOptionType.optimizeEssentialExpenses =>
        l10n.dashboardActionReviewTopGroupTitle,
      FinancialDecisionOptionType.reviewExpenseStructure =>
        l10n.dashboardActionReviewTopGroupTitle,
      FinancialDecisionOptionType.reviewLargeExpense =>
        l10n.dashboardInsightLargestOperationTitle,
      FinancialDecisionOptionType.improveCategorization =>
        l10n.dashboardActionReviewUncategorizedTitle,
      FinancialDecisionOptionType.confirmRecurringOperations =>
        l10n.dashboardActionAddRecurringTitle,
      FinancialDecisionOptionType.collectMoreData =>
        l10n.dashboardActionAddFirstOperationTitle,
      FinancialDecisionOptionType.useExistingReserves =>
        l10n.dashboardRecommendationEmptyTitle,
      FinancialDecisionOptionType.buildSavingsCapacity =>
        l10n.dashboardRadarSavingsPotential,
      FinancialDecisionOptionType.reviseFinancialStrategy =>
        l10n.dashboardAssistantStateTitle,
      FinancialDecisionOptionType.restructureObligations =>
        l10n.dashboardRadarStability,
      FinancialDecisionOptionType.adjustBudgetUnavailable =>
        l10n.dashboardRecommendationEmptyTitle,
      FinancialDecisionOptionType.deferOptionalSpending =>
        l10n.dashboardActionCheckCashFlowTitle,
      FinancialDecisionOptionType.doNothingAndMonitor =>
        l10n.dashboardRecommendationEmptyTitle,
    };
  }

  String _horizonLabel(
    FinancialDecisionOptionEffectHorizon horizon,
    AppLocalizations l10n,
  ) {
    return switch (horizon) {
      FinancialDecisionOptionEffectHorizon.immediate =>
        l10n.dashboardTodayTitle,
      FinancialDecisionOptionEffectHorizon.shortTerm =>
        l10n.dashboardUpcomingTitle,
      FinancialDecisionOptionEffectHorizon.mediumTerm =>
        l10n.dashboardCashFlowTitle,
      FinancialDecisionOptionEffectHorizon.longTerm =>
        l10n.dashboardAssistantStateTitle,
    };
  }

  String _confidenceLabel(
    FinancialRecommendationConfidence confidence,
    AppLocalizations l10n,
  ) {
    return switch (confidence) {
      FinancialRecommendationConfidence.none =>
        l10n.dashboardRadarLowConfidence,
      FinancialRecommendationConfidence.low => l10n.dashboardRadarLowConfidence,
      FinancialRecommendationConfidence.medium =>
        l10n.dashboardRadarEvidenceReady,
      FinancialRecommendationConfidence.high =>
        l10n.dashboardAssistantStateStable,
    };
  }

  Color _problemColor(FinancialProblem problem) {
    return switch (problem.problemType) {
      FinancialProblemType.poorDataReliability => AppColors.chartBlue,
      FinancialProblemType.cashFlowDeficit => AppColors.error,
      _ => AppColors.primary,
    };
  }

  Color _problemBackground(FinancialProblem problem) {
    return switch (problem.problemType) {
      FinancialProblemType.poorDataReliability => AppColors.surfaceBlue,
      FinancialProblemType.cashFlowDeficit => AppColors.surfaceRed,
      _ => AppColors.primaryLight,
    };
  }

  String _analyticsGroupLabel(
    CategoryAnalyticsGroup group,
    AppLocalizations l10n,
  ) {
    return switch (group) {
      CategoryAnalyticsGroup.essentialExpenses =>
        l10n.dashboardAnalyticsEssential,
      CategoryAnalyticsGroup.flexibleExpenses =>
        l10n.dashboardAnalyticsFlexible,
      CategoryAnalyticsGroup.lifestyleEntertainment =>
        l10n.dashboardAnalyticsLifestyle,
      CategoryAnalyticsGroup.financeSavings => l10n.dashboardAnalyticsFinance,
      CategoryAnalyticsGroup.healthDevelopment => l10n.dashboardAnalyticsHealth,
      CategoryAnalyticsGroup.income => l10n.dashboardAnalyticsIncome,
    };
  }

  Color _analyticsGroupColor(CategoryAnalyticsGroup group) {
    return switch (group) {
      CategoryAnalyticsGroup.essentialExpenses => AppColors.chartRed,
      CategoryAnalyticsGroup.flexibleExpenses => AppColors.chartBlue,
      CategoryAnalyticsGroup.lifestyleEntertainment => AppColors.primary,
      CategoryAnalyticsGroup.financeSavings => AppColors.success,
      CategoryAnalyticsGroup.healthDevelopment => AppColors.chartGreen,
      CategoryAnalyticsGroup.income => AppColors.chartGreen,
    };
  }

  String _formatPercent(double value, AppLocalizations l10n) {
    if (value == 0) {
      return '0%';
    }

    final rounded = (value * 100).round();
    if (value > 0 && rounded == 0) {
      return l10n.dashboardPercentLessThanOne;
    }

    return '$rounded%';
  }

  String _allocationLabel(
    FinancialPeriodDistributionBucket bucket,
    AppLocalizations l10n,
  ) {
    return switch (bucket) {
      FinancialPeriodDistributionBucket.mandatoryExpenses =>
        l10n.dashboardAllocationMandatory,
      FinancialPeriodDistributionBucket.flexibleExpenses =>
        l10n.dashboardAllocationFlexibleFinal,
      FinancialPeriodDistributionBucket.wants =>
        l10n.dashboardAllocationWantsLifestyleFinal,
      FinancialPeriodDistributionBucket.savings =>
        l10n.dashboardAllocationSavings,
    };
  }

  IconData _allocationIcon(FinancialPeriodDistributionBucket bucket) {
    return switch (bucket) {
      FinancialPeriodDistributionBucket.mandatoryExpenses =>
        Icons.account_balance_wallet_outlined,
      FinancialPeriodDistributionBucket.flexibleExpenses =>
        Icons.credit_card_outlined,
      FinancialPeriodDistributionBucket.wants => Icons.shopping_bag_outlined,
      FinancialPeriodDistributionBucket.savings => Icons.savings_outlined,
    };
  }

  Color _allocationColor(FinancialPeriodDistributionBucket bucket) {
    return switch (bucket) {
      FinancialPeriodDistributionBucket.mandatoryExpenses => AppColors.primary,
      FinancialPeriodDistributionBucket.flexibleExpenses => AppColors.chartBlue,
      FinancialPeriodDistributionBucket.wants => AppColors.chartPurple,
      FinancialPeriodDistributionBucket.savings => AppColors.success,
    };
  }

  Color _allocationBackgroundColor(FinancialPeriodDistributionBucket bucket) {
    return switch (bucket) {
      FinancialPeriodDistributionBucket.mandatoryExpenses =>
        AppColors.primaryLight,
      FinancialPeriodDistributionBucket.flexibleExpenses =>
        AppColors.surfaceBlue,
      FinancialPeriodDistributionBucket.wants => AppColors.surfacePurple,
      FinancialPeriodDistributionBucket.savings => AppColors.surfaceGreen,
    };
  }

  String _stateTitle(FinancialStateType type, AppLocalizations l10n) {
    return switch (type) {
      FinancialStateType.deficit => l10n.dashboardStateDeficitTitleFinal,
      FinancialStateType.fragileBalance =>
        l10n.dashboardStateFragileBalanceTitleFinal,
      FinancialStateType.stable => l10n.dashboardStateStableTitleFinal,
      FinancialStateType.growth => l10n.dashboardStateGrowthTitleFinal,
      FinancialStateType.strongPosition =>
        l10n.dashboardStateStrongPositionTitleFinal,
    };
  }

  String _stateDescription(FinancialStateType type, AppLocalizations l10n) {
    return switch (type) {
      FinancialStateType.deficit => l10n.dashboardStateDeficitDescription,
      FinancialStateType.fragileBalance =>
        l10n.dashboardStateFragileBalanceDescription,
      FinancialStateType.stable => l10n.dashboardStateStableDescription,
      FinancialStateType.growth => l10n.dashboardStateGrowthDescription,
      FinancialStateType.strongPosition =>
        l10n.dashboardStateStrongPositionDescription,
    };
  }

  IconData _stateIcon(FinancialStateType type) {
    return switch (type) {
      FinancialStateType.deficit => Icons.warning_amber_rounded,
      FinancialStateType.fragileBalance => Icons.balance_outlined,
      FinancialStateType.stable => Icons.check_circle_outline,
      FinancialStateType.growth => Icons.trending_up,
      FinancialStateType.strongPosition => Icons.verified_outlined,
    };
  }

  Color _stateColor(FinancialStateType type) {
    return switch (type) {
      FinancialStateType.deficit => AppColors.error,
      FinancialStateType.fragileBalance => AppColors.primary,
      FinancialStateType.stable => AppColors.chartBlue,
      FinancialStateType.growth => AppColors.success,
      FinancialStateType.strongPosition => AppColors.success,
    };
  }

  Color _stateBackgroundColor(FinancialStateType type) {
    return switch (type) {
      FinancialStateType.deficit => AppColors.surfaceRed,
      FinancialStateType.fragileBalance => AppColors.primaryLight,
      FinancialStateType.stable => AppColors.surfaceBlue,
      FinancialStateType.growth => AppColors.surfaceGreen,
      FinancialStateType.strongPosition => AppColors.surfaceGreen,
    };
  }
}
