import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'evaluation_clock.dart';
import 'financial_evaluation_context.dart';

final evaluationClockProvider = Provider<EvaluationClock>((ref) {
  return const EvaluationClock();
});

final financialEvaluationContextProvider = Provider<FinancialEvaluationContext>(
  (ref) {
    final clock = ref.watch(evaluationClockProvider);
    return FinancialEvaluationContext.forNow(clock.now());
  },
);
