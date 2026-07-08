enum CategoryUiGroup {
  housing,
  transport,
  dailyLife,
  outingsShopping,
  leisure,
  financeSavings,
  health,
  development,
  income;

  static CategoryUiGroup fromLegacyGroupKey(String value) {
    return switch (value) {
      'housing' || 'essential_expenses' => CategoryUiGroup.housing,
      'transport' => CategoryUiGroup.transport,
      'food' || 'other' || 'flexible_expenses' => CategoryUiGroup.dailyLife,
      'lifestyle' || 'lifestyle_entertainment' => CategoryUiGroup.leisure,
      'finance' ||
      'investments' ||
      'finance_savings' => CategoryUiGroup.financeSavings,
      'health' || 'health_development' => CategoryUiGroup.health,
      'income' ||
      'salary' ||
      'business' ||
      'benefits' => CategoryUiGroup.income,
      _ => throw ArgumentError.value(
        value,
        'value',
        'Invalid UI category group',
      ),
    };
  }
}
