enum CategoryType {
  expense,
  income;

  static CategoryType fromJson(String value) {
    return switch (value) {
      'expense' => CategoryType.expense,
      'income' => CategoryType.income,
      _ => throw ArgumentError.value(value, 'value', 'Invalid category type'),
    };
  }

  String toJson() {
    return switch (this) {
      CategoryType.expense => 'expense',
      CategoryType.income => 'income',
    };
  }
}