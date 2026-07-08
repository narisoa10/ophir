final class DashboardTodaySummary {
  const DashboardTodaySummary({
    required this.income,
    required this.expenses,
    required this.net,
    required this.operationCount,
  });

  final double income;
  final double expenses;
  final double net;
  final int operationCount;
}
