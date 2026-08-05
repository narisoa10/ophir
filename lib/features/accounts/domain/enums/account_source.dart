enum AccountSource {
  manual;

  static AccountSource fromJson(String value) {
    return switch (value) {
      'manual' => AccountSource.manual,
      _ => throw ArgumentError.value(value, 'value', 'Invalid account source'),
    };
  }

  String toJson() {
    return switch (this) {
      AccountSource.manual => 'manual',
    };
  }
}
