enum CategoryAnalyticsGroup {
  essentialExpenses,
  flexibleExpenses,
  lifestyleEntertainment,
  financeSavings,
  healthDevelopment,
  income;

  static CategoryAnalyticsGroup fromLegacyGroupKey(String value) {
    return switch (value) {
      'essential_expenses' ||
      'housing' ||
      'food' ||
      'transport' => CategoryAnalyticsGroup.essentialExpenses,
      'flexible_expenses' || 'other' => CategoryAnalyticsGroup.flexibleExpenses,
      'lifestyle_entertainment' ||
      'lifestyle' => CategoryAnalyticsGroup.lifestyleEntertainment,
      'finance_savings' ||
      'finance' ||
      'investments' => CategoryAnalyticsGroup.financeSavings,
      'health_development' ||
      'health' => CategoryAnalyticsGroup.healthDevelopment,
      'income' ||
      'salary' ||
      'business' ||
      'benefits' => CategoryAnalyticsGroup.income,
      _ => throw ArgumentError.value(
        value,
        'value',
        'Invalid analytics category group',
      ),
    };
  }

  String toJson() {
    return switch (this) {
      CategoryAnalyticsGroup.essentialExpenses => 'essential_expenses',
      CategoryAnalyticsGroup.flexibleExpenses => 'flexible_expenses',
      CategoryAnalyticsGroup.lifestyleEntertainment =>
        'lifestyle_entertainment',
      CategoryAnalyticsGroup.financeSavings => 'finance_savings',
      CategoryAnalyticsGroup.healthDevelopment => 'health_development',
      CategoryAnalyticsGroup.income => 'income',
    };
  }
}
