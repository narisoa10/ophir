enum OperationSource {
  manual,
  plaid,
  plaidInternalTransfer;

  static OperationSource fromJson(String value) {
    return switch (value) {
      'manual' => OperationSource.manual,
      'plaid' => OperationSource.plaid,
      'plaid_internal_transfer' => OperationSource.plaidInternalTransfer,
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
      OperationSource.plaidInternalTransfer => 'plaid_internal_transfer',
    };
  }
}
