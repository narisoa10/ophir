final class EvaluationClock {
  const EvaluationClock({DateTime? fixedNow}) : _fixedNow = fixedNow;

  final DateTime? _fixedNow;

  DateTime now() {
    return _fixedNow ?? DateTime.now();
  }
}
