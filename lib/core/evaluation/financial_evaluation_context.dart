import 'financial_evaluation_period.dart';

final class FinancialEvaluationContext {
  FinancialEvaluationContext({required this.now, required this.currentMonth});

  factory FinancialEvaluationContext.forNow(DateTime now) {
    return FinancialEvaluationContext(
      now: now,
      currentMonth: FinancialEvaluationPeriod(
        start: DateTime(now.year, now.month),
        end: DateTime(now.year, now.month + 1),
      ),
    );
  }

  final DateTime now;
  final FinancialEvaluationPeriod currentMonth;
}
