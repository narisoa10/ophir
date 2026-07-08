import '../entities/financial_deviation.dart';
import '../entities/financial_deviation_severity.dart';
import '../entities/financial_deviation_type.dart';
import '../entities/financial_problem.dart';
import '../entities/financial_problem_catalog.dart';
import '../entities/financial_problem_rule.dart';
import 'financial_problem_result_builder.dart';

final class SpendingProblemService {
  const SpendingProblemService({
    this.resultBuilder = const FinancialProblemResultBuilder(),
  });

  final FinancialProblemResultBuilder resultBuilder;

  List<FinancialProblem> detect(List<FinancialDeviation> deviations) {
    return [
      ..._detectRule(deviations, FinancialProblemCatalog.expensePressure),
      ..._detectRule(
        deviations,
        FinancialProblemCatalog.discretionarySpendingPressure,
      ),
      ..._detectRule(deviations, FinancialProblemCatalog.essentialCostPressure),
    ];
  }

  List<FinancialProblem> _detectRule(
    List<FinancialDeviation> deviations,
    FinancialProblemRule rule,
  ) {
    final required = _requiredDeviations(deviations, rule);
    if (required.isEmpty) {
      return const [];
    }
    final supporting = _deviationsFor(
      deviations,
      rule.supportingDeviationTypes,
    );
    final hasEnoughSupport =
        supporting.length >= rule.minimumSupportingSignals ||
        (rule.allowsIsolatedMediumOrHighSignal &&
            required.any(_isMediumOrHigh));
    if (!hasEnoughSupport) {
      return const [];
    }

    return [
      resultBuilder.detected(
        rule: rule,
        requiredDeviations: required,
        supportingDeviations: supporting,
        hasWeakDataQuality: _hasWeakDataQuality(deviations),
        hasLimitedSupportingEvidence:
            supporting.length < rule.minimumSupportingSignals,
      ),
    ];
  }

  List<FinancialDeviation> _requiredDeviations(
    List<FinancialDeviation> deviations,
    FinancialProblemRule rule,
  ) {
    return deviations
        .where(
          (deviation) =>
              rule.requiredDeviationTypes.contains(deviation.deviationType),
        )
        .toList(growable: false);
  }

  List<FinancialDeviation> _deviationsFor(
    List<FinancialDeviation> deviations,
    List<FinancialDeviationType> types,
  ) {
    return deviations
        .where((deviation) => types.contains(deviation.deviationType))
        .toList(growable: false);
  }

  bool _isMediumOrHigh(FinancialDeviation deviation) {
    return deviation.severity == FinancialDeviationSeverity.medium ||
        deviation.severity == FinancialDeviationSeverity.high;
  }

  bool _hasWeakDataQuality(List<FinancialDeviation> deviations) {
    return deviations.any(
      (deviation) =>
          deviation.deviationType == FinancialDeviationType.weakDataQuality,
    );
  }
}
