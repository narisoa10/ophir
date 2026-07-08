import '../entities/financial_decision_option_applicability.dart';
import '../entities/financial_decision_option_availability_reason.dart';
import '../entities/financial_decision_option_rule.dart';
import '../entities/financial_decision_option_status.dart';
import '../entities/financial_decision_option_type.dart';
import '../entities/financial_problem.dart';
import '../entities/financial_problem_confidence.dart';
import '../entities/financial_problem_impact.dart';
import '../entities/financial_problem_type.dart';

final class FinancialDecisionOptionAvailabilityPolicy {
  const FinancialDecisionOptionAvailabilityPolicy();

  FinancialDecisionOptionApplicability applicabilityFor({
    required FinancialDecisionOptionRule rule,
    required List<FinancialProblem> linkedProblems,
  }) {
    if (_isFutureUnavailable(rule.optionType)) {
      return FinancialDecisionOptionApplicability.futureUnavailable;
    }
    if (linkedProblems.isEmpty) {
      return FinancialDecisionOptionApplicability.notApplicable;
    }
    if (rule.optionType ==
            FinancialDecisionOptionType.reduceRecurringCommitments &&
        !_hasFixedCommitmentEvidence(linkedProblems)) {
      return FinancialDecisionOptionApplicability.notApplicable;
    }
    if (rule.optionType == FinancialDecisionOptionType.collectMoreData &&
        !_hasPoorDataOrLowConfidence(linkedProblems)) {
      return FinancialDecisionOptionApplicability.conditional;
    }
    if (rule.optionType == FinancialDecisionOptionType.doNothingAndMonitor &&
        !_hasPoorDataOrLowConfidence(linkedProblems)) {
      return FinancialDecisionOptionApplicability.conditional;
    }
    return FinancialDecisionOptionApplicability.applicable;
  }

  FinancialDecisionOptionStatus statusFor(
    FinancialDecisionOptionApplicability applicability,
  ) {
    return switch (applicability) {
      FinancialDecisionOptionApplicability.applicable =>
        FinancialDecisionOptionStatus.available,
      FinancialDecisionOptionApplicability.conditional =>
        FinancialDecisionOptionStatus.conditional,
      FinancialDecisionOptionApplicability.notApplicable =>
        FinancialDecisionOptionStatus.unavailable,
      FinancialDecisionOptionApplicability.futureUnavailable =>
        FinancialDecisionOptionStatus.futureUnavailable,
    };
  }

  List<FinancialDecisionOptionAvailabilityReason> reasonsFor({
    required FinancialDecisionOptionRule rule,
    required List<FinancialProblem> linkedProblems,
  }) {
    final applicability = applicabilityFor(
      rule: rule,
      linkedProblems: linkedProblems,
    );
    final reasons = <FinancialDecisionOptionAvailabilityReason>[];
    if (applicability ==
        FinancialDecisionOptionApplicability.futureUnavailable) {
      reasons.add(
        FinancialDecisionOptionAvailabilityReason(
          reasonId: 'availability.future.${rule.optionType.name}',
        ),
      );
    }
    if (applicability == FinancialDecisionOptionApplicability.notApplicable) {
      reasons.add(
        FinancialDecisionOptionAvailabilityReason(
          reasonId: 'availability.notApplicable.${rule.optionType.name}',
        ),
      );
    }
    if (applicability == FinancialDecisionOptionApplicability.conditional) {
      reasons.add(
        FinancialDecisionOptionAvailabilityReason(
          reasonId: 'availability.conditional.${rule.optionType.name}',
        ),
      );
    }
    return List.unmodifiable(reasons);
  }

  bool _isFutureUnavailable(FinancialDecisionOptionType optionType) {
    return switch (optionType) {
      FinancialDecisionOptionType.useExistingReserves ||
      FinancialDecisionOptionType.reviseFinancialStrategy ||
      FinancialDecisionOptionType.restructureObligations ||
      FinancialDecisionOptionType.adjustBudgetUnavailable => true,
      _ => false,
    };
  }

  bool _hasFixedCommitmentEvidence(List<FinancialProblem> problems) {
    return problems.any(
      (problem) =>
          problem.problemType == FinancialProblemType.fixedCommitmentPressure ||
          problem.impact == FinancialProblemImpact.commitmentFlexibility,
    );
  }

  bool _hasPoorDataOrLowConfidence(List<FinancialProblem> problems) {
    return problems.any(
      (problem) =>
          problem.problemType == FinancialProblemType.poorDataReliability ||
          problem.confidence == FinancialProblemConfidence.low ||
          problem.confidence == FinancialProblemConfidence.none,
    );
  }
}
