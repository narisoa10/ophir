import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:ophir/core/localization/generated/app_localizations_en.dart';
import 'package:ophir/features/assistant/domain/entities/assistant_dashboard_briefing.dart';
import 'package:ophir/features/assistant/domain/entities/assistant_dashboard_radar.dart';
import 'package:ophir/features/assistant/domain/entities/financial_fact.dart';
import 'package:ophir/features/assistant/domain/entities/financial_fact_confidence.dart';
import 'package:ophir/features/assistant/domain/entities/financial_fact_source.dart';
import 'package:ophir/features/assistant/domain/entities/financial_fact_type.dart';
import 'package:ophir/features/assistant/domain/entities/financial_facts_snapshot.dart';
import 'package:ophir/features/assistant/domain/entities/financial_model_confidence.dart';
import 'package:ophir/features/assistant/domain/entities/financial_model_period.dart';
import 'package:ophir/features/assistant/domain/entities/financial_period_distribution.dart';
import 'package:ophir/features/assistant/domain/entities/financial_period_distribution_bucket.dart';
import 'package:ophir/features/assistant/domain/entities/financial_period_distribution_item.dart';
import 'package:ophir/features/assistant/domain/entities/financial_state.dart';
import 'package:ophir/features/assistant/domain/entities/financial_state_confidence.dart';
import 'package:ophir/features/assistant/domain/entities/financial_state_type.dart';
import 'package:ophir/features/dashboard/presentation/adapters/dashboard_presentation_adapter.dart';
import 'package:ophir/features/operations/domain/enums/operation_recurrence.dart';
import 'package:ophir/features/operations/domain/enums/operation_type.dart';

void main() {
  group('DashboardPresentationAdapter', () {
    const adapter = DashboardPresentationAdapter();

    test('filters today facts with injected now', () {
      final now = DateTime(2030, 5, 10, 12);
      final presentation = adapter.toPresentation(
        briefing: _briefing(
          now: now,
          facts: [
            _operationFact(
              id: 'income-today',
              type: FinancialFactType.incomeOperation,
              operationType: OperationType.income,
              amount: 100,
              occurredAt: DateTime(2030, 5, 10, 8),
            ),
            _operationFact(
              id: 'expense-yesterday',
              type: FinancialFactType.expenseOperation,
              operationType: OperationType.expense,
              amount: 40,
              occurredAt: DateTime(2030, 5, 9, 18),
            ),
          ],
        ),
        l10n: AppLocalizationsEn(),
        now: now,
        formatDate: _formatDate,
        formatMoney: _formatMoney,
      );

      expect(presentation.today.income, '100.0 CAD');
      expect(presentation.today.expenses, '0.0 CAD');
      expect(presentation.today.net, '100.0 CAD');
      expect(presentation.today.operationCount, contains('1'));
    });

    test('calculates upcoming recurring dates with injected now', () {
      final now = DateTime(2030, 3, 15, 12);
      final presentation = adapter.toPresentation(
        briefing: _briefing(
          now: now,
          facts: [
            _operationFact(
              id: 'rent-operation',
              operationId: 'rent',
              type: FinancialFactType.expenseOperation,
              operationType: OperationType.expense,
              amount: 50,
              occurredAt: DateTime(2030, 1, 1),
            ),
            _operationFact(
              id: 'rent-recurring',
              operationId: 'rent',
              type: FinancialFactType.recurringOperation,
              operationType: OperationType.expense,
              amount: 50,
              occurredAt: DateTime(2030, 1, 1),
              recurrence: OperationRecurrence.monthly,
            ),
          ],
        ),
        l10n: AppLocalizationsEn(),
        now: now,
        formatDate: _formatDate,
        formatMoney: _formatMoney,
      );

      expect(presentation.upcoming, hasLength(1));
      expect(presentation.upcoming.single.date, '2030-04-01');
      expect(presentation.upcoming.single.amount, '-50.0 CAD');
    });

    test('does not create DateTime.now inside adapter', () {
      final source = File(
        'lib/features/dashboard/presentation/adapters/dashboard_presentation_adapter.dart',
      ).readAsStringSync();

      expect(source, isNot(contains('DateTime.now()')));
    });

    test('formats zero distribution percent as 0%', () {
      final now = DateTime(2030, 5, 10, 12);
      final presentation = adapter.toPresentation(
        briefing: _briefing(
          now: now,
          facts: const [],
          distributionItems: [_distributionItem(amount: 0, percent: 0)],
        ),
        l10n: AppLocalizationsEn(),
        now: now,
        formatDate: _formatDate,
        formatMoney: _formatMoney,
      );

      expect(
        presentation.assistantSummary.financialState.items.single.percent,
        '0%',
      );
    });

    test('formats positive sub-one distribution percent as less than one', () {
      final now = DateTime(2030, 5, 10, 12);
      final presentation = adapter.toPresentation(
        briefing: _briefing(
          now: now,
          facts: const [],
          distributionItems: [
            _distributionItem(amount: 10, percent: 10 / 5000),
          ],
        ),
        l10n: AppLocalizationsEn(),
        now: now,
        formatDate: _formatDate,
        formatMoney: _formatMoney,
      );

      expect(
        presentation.assistantSummary.financialState.items.single.percent,
        '<1%',
      );
    });

    test('formats rounded distribution percent normally', () {
      final now = DateTime(2030, 5, 10, 12);
      final presentation = adapter.toPresentation(
        briefing: _briefing(
          now: now,
          facts: const [],
          distributionItems: [
            _distributionItem(amount: 100, percent: 100 / 5000),
          ],
        ),
        l10n: AppLocalizationsEn(),
        now: now,
        formatDate: _formatDate,
        formatMoney: _formatMoney,
      );

      expect(
        presentation.assistantSummary.financialState.items.single.percent,
        '2%',
      );
    });
  });
}

AssistantDashboardBriefing _briefing({
  required DateTime now,
  required List<FinancialFact> facts,
  List<FinancialPeriodDistributionItem> distributionItems = const [],
}) {
  final period = FinancialModelPeriod(
    start: DateTime(now.year, now.month),
    end: DateTime(now.year, now.month + 1),
  );

  return AssistantDashboardBriefing(
    factsSnapshot: FinancialFactsSnapshot(facts: facts, dataGaps: const []),
    modelResults: const [],
    deviations: const [],
    problems: const [],
    decisionOptions: const [],
    recommendation: null,
    explanation: null,
    radar: const AssistantDashboardRadar(
      axes: [],
      isLowConfidence: false,
      evidenceModelIds: [],
    ),
    primaryProblem: null,
    financialState: FinancialState(
      type: FinancialStateType.stable,
      confidence: FinancialStateConfidence.high,
      period: period,
      currencyCode: 'CAD',
      income: 0,
      expenses: 0,
      net: 0,
      evidenceModelIds: const [],
      limitations: const [],
    ),
    periodDistribution: FinancialPeriodDistribution(
      period: period,
      currencyCode: 'CAD',
      incomeTotal: 0,
      expenseTotal: 0,
      netCashFlow: 0,
      items: distributionItems,
      confidence: FinancialModelConfidence.high,
      evidenceModelIds: const [],
      limitations: const [],
    ),
  );
}

FinancialFact _operationFact({
  required String id,
  String? operationId,
  required FinancialFactType type,
  required OperationType operationType,
  required double amount,
  required DateTime occurredAt,
  OperationRecurrence? recurrence,
}) {
  return FinancialFact(
    id: id,
    type: type,
    source: FinancialFactSource.manualRecorded,
    confidence: FinancialFactConfidence.high,
    operationId: operationId ?? id,
    operationType: operationType,
    amount: amount,
    currencyCode: 'CAD',
    occurredAt: occurredAt,
    recurrence: recurrence,
  );
}

FinancialPeriodDistributionItem _distributionItem({
  required double amount,
  required double percent,
}) {
  return FinancialPeriodDistributionItem(
    bucket: FinancialPeriodDistributionBucket.flexibleExpenses,
    amount: amount,
    percent: percent,
    limitations: const [],
  );
}

String _formatDate(DateTime date) {
  final month = date.month.toString().padLeft(2, '0');
  final day = date.day.toString().padLeft(2, '0');
  return '${date.year}-$month-$day';
}

String _formatMoney(double amount, String currencyCode) {
  return '$amount $currencyCode';
}
