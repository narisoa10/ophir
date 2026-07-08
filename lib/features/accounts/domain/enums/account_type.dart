enum AccountType {
  cash,
  bank,
  card,
  creditCard,
  savings,
  investment,
  loan,
  wallet,
  other;

  static AccountType fromJson(String value) {
    return switch (value) {
      'cash' => AccountType.cash,
      'bank' => AccountType.bank,
      'card' => AccountType.card,
      'credit_card' => AccountType.creditCard,
      'savings' => AccountType.savings,
      'investment' => AccountType.investment,
      'loan' => AccountType.loan,
      'wallet' => AccountType.wallet,
      'other' => AccountType.other,
      _ => throw ArgumentError.value(value, 'value', 'Invalid account type'),
    };
  }

  String toJson() {
    return switch (this) {
      AccountType.cash => 'cash',
      AccountType.bank => 'bank',
      AccountType.card => 'card',
      AccountType.creditCard => 'credit_card',
      AccountType.savings => 'savings',
      AccountType.investment => 'investment',
      AccountType.loan => 'loan',
      AccountType.wallet => 'wallet',
      AccountType.other => 'other',
    };
  }
}