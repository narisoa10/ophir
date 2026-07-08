import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ophir/core/evaluation/evaluation_clock.dart';
import 'package:ophir/core/evaluation/financial_evaluation_context.dart';
import 'package:ophir/core/evaluation/financial_evaluation_context_provider.dart';

void main() {
  group('financialEvaluationContextProvider', () {
    test('returns stable now and current month period', () {
      final fixedNow = DateTime(2030, 12, 15, 10, 30);
      final container = ProviderContainer(
        overrides: [
          evaluationClockProvider.overrideWithValue(
            EvaluationClock(fixedNow: fixedNow),
          ),
        ],
      );
      addTearDown(container.dispose);

      final context = container.read(financialEvaluationContextProvider);

      expect(context.now, fixedNow);
      expect(context.currentMonth.start, DateTime(2030, 12));
      expect(context.currentMonth.end, DateTime(2031));
      expect(context.currentMonth.contains(fixedNow), isTrue);
    });

    test('provider override works in tests', () {
      final fixedNow = DateTime(2040, 2, 20);
      final fixedContext = FinancialEvaluationContext.forNow(fixedNow);
      final container = ProviderContainer(
        overrides: [
          financialEvaluationContextProvider.overrideWithValue(fixedContext),
        ],
      );
      addTearDown(container.dispose);

      final context = container.read(financialEvaluationContextProvider);

      expect(context, same(fixedContext));
      expect(context.now, fixedNow);
      expect(context.currentMonth.start, DateTime(2040, 2));
      expect(context.currentMonth.end, DateTime(2040, 3));
    });
  });
}
