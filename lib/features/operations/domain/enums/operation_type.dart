enum OperationType {
  expense,
  income,
  transfer;

  static OperationType fromJson(String value) {
    return switch (value) {
      'expense' => OperationType.expense,
      'income' => OperationType.income,
      'transfer' => OperationType.transfer,
      _ => throw ArgumentError.value(value, 'value', 'Invalid operation type'),
    };
  }

  String toJson() {
    return switch (this) {
      OperationType.expense => 'expense',
      OperationType.income => 'income',
      OperationType.transfer => 'transfer',
    };
  }
}
