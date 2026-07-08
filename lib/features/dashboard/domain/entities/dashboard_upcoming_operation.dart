import '../../../operations/domain/entities/operation.dart';

final class DashboardUpcomingOperation {
  const DashboardUpcomingOperation({
    required this.operation,
    required this.nextDate,
  });

  final Operation operation;
  final DateTime nextDate;
}
