final class FinancialModelPeriod {
  FinancialModelPeriod({required this.start, required this.end})
    : assert(
        end.isAfter(start),
        'FinancialModelPeriod end must be after start.',
      );

  final DateTime start;
  final DateTime end;

  bool contains(DateTime value) {
    return !value.isBefore(start) && value.isBefore(end);
  }

  int get dayCount => end.difference(start).inDays;
}
