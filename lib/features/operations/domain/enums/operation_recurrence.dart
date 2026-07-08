enum OperationRecurrence {
  none,
  daily,
  weekly,
  biweekly,
  monthly,
  yearly;

  static OperationRecurrence fromJson(String value) {
    return switch (value) {
      'none' => OperationRecurrence.none,
      'daily' => OperationRecurrence.daily,
      'weekly' => OperationRecurrence.weekly,
      'biweekly' => OperationRecurrence.biweekly,
      'monthly' => OperationRecurrence.monthly,
      'yearly' => OperationRecurrence.yearly,
      _ => throw ArgumentError.value(
        value,
        'value',
        'Invalid operation recurrence',
      ),
    };
  }

  String toJson() {
    return switch (this) {
      OperationRecurrence.none => 'none',
      OperationRecurrence.daily => 'daily',
      OperationRecurrence.weekly => 'weekly',
      OperationRecurrence.biweekly => 'biweekly',
      OperationRecurrence.monthly => 'monthly',
      OperationRecurrence.yearly => 'yearly',
    };
  }
}
