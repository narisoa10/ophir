final class FinancialEvaluationPeriod {
  FinancialEvaluationPeriod({required this.start, required this.end})
    : assert(
        end.isAfter(start),
        'FinancialEvaluationPeriod end must be after start.',
      );

  final DateTime start;
  final DateTime end;

  bool contains(DateTime value) {
    return !value.isBefore(start) && value.isBefore(end);
  }

  int get dayCount {
    return end.difference(start).inDays;
  }
}
