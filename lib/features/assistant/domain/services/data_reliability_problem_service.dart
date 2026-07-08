import '../entities/financial_deviation.dart';
import '../entities/financial_deviation_type.dart';
import '../entities/financial_problem.dart';
import '../entities/financial_problem_catalog.dart';
import 'financial_problem_result_builder.dart';

final class DataReliabilityProblemService {
  const DataReliabilityProblemService({
    this.resultBuilder = const FinancialProblemResultBuilder(),
  });

  final FinancialProblemResultBuilder resultBuilder;

  List<FinancialProblem> detect(List<FinancialDeviation> deviations) {
    final required = deviations
        .where(
          (deviation) =>
              deviation.deviationType == FinancialDeviationType.weakDataQuality,
        )
        .toList(growable: false);
    if (required.isEmpty) {
      return const [];
    }

    return [
      resultBuilder.detected(
        rule: FinancialProblemCatalog.poorDataReliability,
        requiredDeviations: required,
        supportingDeviations: const [],
        hasWeakDataQuality: false,
        hasLimitedSupportingEvidence: false,
      ),
    ];
  }
}
