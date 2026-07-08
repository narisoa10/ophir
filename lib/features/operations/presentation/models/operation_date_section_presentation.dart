import 'operation_presentation.dart';

final class OperationDateSectionPresentation {
  const OperationDateSectionPresentation({
    required this.date,
    required this.runningBalanceAfterDate,
    required this.operations,
  });

  final String date;
  final String runningBalanceAfterDate;
  final List<OperationPresentation> operations;
}
