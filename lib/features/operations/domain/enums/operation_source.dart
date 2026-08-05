enum OperationSource {
  manual;

  static OperationSource fromJson(String value) {
    return switch (value) {
      'manual' => OperationSource.manual,
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
    };
  }
}
