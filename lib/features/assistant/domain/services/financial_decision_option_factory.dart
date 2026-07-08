import '../entities/financial_decision_objective.dart';
import '../entities/financial_decision_option.dart';
import '../entities/financial_decision_option_evidence.dart';
import '../entities/financial_decision_option_impact.dart';
import '../entities/financial_decision_option_metadata.dart';
import '../entities/financial_decision_option_rule.dart';
import '../entities/financial_problem.dart';
import 'financial_decision_option_availability_policy.dart';

final class FinancialDecisionOptionFactory {
  const FinancialDecisionOptionFactory({
    this.engineVersion = 'financial-decision-options-v1',
    this.availabilityPolicy = const FinancialDecisionOptionAvailabilityPolicy(),
  });

  final String engineVersion;
  final FinancialDecisionOptionAvailabilityPolicy availabilityPolicy;

  FinancialDecisionOption create({
    required FinancialDecisionOptionRule rule,
    required List<FinancialProblem> linkedProblems,
    required List<FinancialDecisionObjective> objectives,
  }) {
    final applicability = availabilityPolicy.applicabilityFor(
      rule: rule,
      linkedProblems: linkedProblems,
    );
    final sortedProblems = [...linkedProblems]
      ..sort((a, b) => a.problemId.compareTo(b.problemId));
    final generatedAt = sortedProblems.isEmpty
        ? DateTime.fromMicrosecondsSinceEpoch(0)
        : sortedProblems
              .map((problem) => problem.metadata.calculatedAt)
              .reduce((a, b) => a.isAfter(b) ? a : b);

    return FinancialDecisionOption(
      optionId: _optionId(rule, sortedProblems),
      optionType: rule.optionType,
      status: availabilityPolicy.statusFor(applicability),
      applicability: applicability,
      linkedProblemIds: List.unmodifiable(
        sortedProblems.map((problem) => problem.problemId),
      ),
      solvesProblemTypes: List.unmodifiable(
        sortedProblems.map((problem) => problem.problemType).toSet(),
      ),
      mayWorsenProblemTypes: List.unmodifiable(rule.mayWorsenProblemTypes),
      objectives: List.unmodifiable(
        objectives.where(
          (objective) => sortedProblems.any(
            (problem) => problem.problemId == objective.sourceProblemId,
          ),
        ),
      ),
      targets: List.unmodifiable(rule.targets),
      expectedModelChanges: List.unmodifiable(rule.expectedModelChanges),
      impact: FinancialDecisionOptionImpact(
        isQuantitative: rule.expectedModelChanges.any(
          (change) => change.expectedChange != null,
        ),
        effectHorizon: rule.effectHorizon,
      ),
      cost: rule.cost,
      risk: rule.risk,
      conditions: List.unmodifiable(rule.conditions),
      limitations: List.unmodifiable(rule.limitations),
      availabilityReasons: availabilityPolicy.reasonsFor(
        rule: rule,
        linkedProblems: sortedProblems,
      ),
      evidence: FinancialDecisionOptionEvidence(
        sourceProblemIds: List.unmodifiable(
          sortedProblems.map((problem) => problem.problemId).toSet(),
        ),
        sourceProblemTypes: List.unmodifiable(
          sortedProblems.map((problem) => problem.problemType).toSet(),
        ),
        sourceDeviationIds: List.unmodifiable(
          sortedProblems
              .expand((problem) => problem.evidence.sourceDeviationIds)
              .where(_isAllowedEvidenceId)
              .toSet(),
        ),
        sourceModelIds: List.unmodifiable(
          sortedProblems
              .expand((problem) => problem.evidence.sourceModelIds)
              .where(_isAllowedEvidenceId)
              .toSet(),
        ),
      ),
      metadata: FinancialDecisionOptionMetadata(
        generatedAt: generatedAt,
        engineVersion: engineVersion,
        ruleId: rule.ruleId,
      ),
      effectHorizon: rule.effectHorizon,
    );
  }

  String _optionId(
    FinancialDecisionOptionRule rule,
    List<FinancialProblem> problems,
  ) {
    final problemKey = problems
        .map(
          (problem) =>
              problem.problemId.replaceAll(RegExp('[^a-zA-Z0-9]'), '_'),
        )
        .join('__');
    return 'financial.decision.option.${rule.optionType.name}.$problemKey';
  }

  bool _isAllowedEvidenceId(String id) {
    return !id.startsWith('operation:') &&
        !id.startsWith('category:') &&
        !id.startsWith('account:') &&
        !id.startsWith('fact:');
  }
}
