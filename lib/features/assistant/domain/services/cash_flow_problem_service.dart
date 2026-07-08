import '../entities/financial_deviation.dart';
import '../entities/financial_deviation_type.dart';
import '../entities/financial_problem.dart';
import '../entities/financial_problem_catalog.dart';
import 'financial_problem_result_builder.dart';

final class CashFlowProblemService {
  const CashFlowProblemService({
    this.resultBuilder = const FinancialProblemResultBuilder(),
  });

  final FinancialProblemResultBuilder resultBuilder;

  List<FinancialProblem> detect(List<FinancialDeviation> deviations) {
    final required = _deviationsFor(
      deviations,
      FinancialProblemCatalog.cashFlowDeficit.requiredDeviationTypes,
    );
    if (required.isEmpty) {
      return const [];
    }

    return [
      resultBuilder.detected(
        rule: FinancialProblemCatalog.cashFlowDeficit,
        requiredDeviations: required,
        supportingDeviations: _deviationsFor(
          deviations,
          FinancialProblemCatalog.cashFlowDeficit.supportingDeviationTypes,
        ),
        hasWeakDataQuality: _hasWeakDataQuality(deviations),
        hasLimitedSupportingEvidence: false,
      ),
    ];
  }

  List<FinancialDeviation> _deviationsFor(
    List<FinancialDeviation> deviations,
    List<FinancialDeviationType> types,
  ) {
    return deviations
        .where((deviation) => types.contains(deviation.deviationType))
        .toList(growable: false);
  }

  bool _hasWeakDataQuality(List<FinancialDeviation> deviations) {
    return deviations.any(
      (deviation) =>
          deviation.deviationType == FinancialDeviationType.weakDataQuality,
    );
  }
}
