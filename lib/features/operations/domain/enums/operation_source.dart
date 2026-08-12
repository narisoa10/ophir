enum OperationSource {
  manual,
  plaid;

  static OperationSource fromJson(String value) {
    return switch (value) {
      'manual' => OperationSource.manual,
      'plaid' => OperationSource.plaid,
      _ => throw ArgumentError.value(
        value,
        'value',
        'Invalid operation source',
      ),
    };
  }

  String toJson() {
    return switch (this) {
      OperationSource.manual => 'manual',
      OperationSource.plaid => 'plaid',
    };
  }
}
