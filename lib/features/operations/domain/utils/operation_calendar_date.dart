import '../../domain/entities/operation.dart';

DateTime operationCalendarDateValue(DateTime value) {
  return DateTime(value.year, value.month, value.day);
}

DateTime operationDateFromJson(String value) {
  final datePart = value.length >= 10 ? value.substring(0, 10) : value;
  final parts = datePart.split('-');

  if (parts.length != 3) {
    throw FormatException('Invalid operation date', value);
  }

  return DateTime(
    int.parse(parts[0]),
    int.parse(parts[1]),
    int.parse(parts[2]),
  );
}

String operationDateToJson(DateTime value) {
  final date = operationCalendarDateValue(value);
  final year = date.year.toString().padLeft(4, '0');
  final month = date.month.toString().padLeft(2, '0');
  final day = date.day.toString().padLeft(2, '0');

  return '$year-$month-$day';
}

DateTime operationCalendarDate(Operation operation) {
  return operationCalendarDateValue(operation.occurredAt);
}

bool operationIsInMonth(Operation operation, DateTime selectedMonth) {
  final calendarDate = operationCalendarDate(operation);

  return calendarDate.year == selectedMonth.year &&
      calendarDate.month == selectedMonth.month;
}
