import '../entities/financial_decision_objective.dart';
import '../entities/financial_decision_option.dart';
import '../entities/financial_decision_option_applicability.dart';
import '../entities/financial_decision_option_evidence.dart';
import '../entities/financial_decision_option_metadata.dart';
import '../entities/financial_decision_option_status.dart';
import '../entities/financial_decision_option_type.dart';
import 'financial_decision_option_catalog.dart';

final class FinancialDecisionOptionDeduplicationPolicy {
  const FinancialDecisionOptionDeduplicationPolicy();

  List<FinancialDecisionOption> merge(List<FinancialDecisionOption> options) {
    final byType =
        <FinancialDecisionOptionType, List<FinancialDecisionOption>>{};
    for (final option in options) {
      byType.putIfAbsent(option.optionType, () => []).add(option);
    }

    final merged = <FinancialDecisionOption>[];
    for (final rule in FinancialDecisionOptionCatalog.rules) {
      final group = byType[rule.optionType];
      if (group == null || group.isEmpty) {
        continue;
      }
      merged.add(_mergeGroup(group));
    }
    return List.unmodifiable(merged);
  }

  FinancialDecisionOption _mergeGroup(List<FinancialDecisionOption> group) {
    final first = group.first;
    final linkedProblemIds = _uniqueSorted(
      group.expand((option) => option.linkedProblemIds),
    );
    final objectives = _uniqueObjectives(
      group.expand((option) => option.objectives),
    );
    final generatedAt = group
        .map((option) => option.metadata.generatedAt)
        .reduce((a, b) => a.isAfter(b) ? a : b);

    return FinancialDecisionOption(
      optionId:
          'financial.decision.option.${first.optionType.name}.'
          '${linkedProblemIds.join('__')}',
      optionType: first.optionType,
      status: _leastAvailableStatus(group.map((option) => option.status)),
      applicability: _leastAvailableApplicability(
        group.map((option) => option.applicability),
      ),
      linkedProblemIds: linkedProblemIds,
      solvesProblemTypes: List.unmodifiable(
        group.expand((option) => option.solvesProblemTypes).toSet(),
      ),
      mayWorsenProblemTypes: List.unmodifiable(
        group.expand((option) => option.mayWorsenProblemTypes).toSet(),
      ),
      objectives: objectives,
      targets: first.targets,
      expectedModelChanges: first.expectedModelChanges,
      impact: first.impact,
      cost: first.cost,
      risk: first.risk,
      conditions: first.conditions,
      limitations: first.limitations,
      availabilityReasons: List.unmodifiable(
        group.expand((option) => option.availabilityReasons).toList(),
      ),
      evidence: FinancialDecisionOptionEvidence(
        sourceProblemIds: _uniqueSorted(
          group.expand((option) => option.evidence.sourceProblemIds),
        ),
        sourceProblemTypes: List.unmodifiable(
          group.expand((option) => option.evidence.sourceProblemTypes).toSet(),
        ),
        sourceDeviationIds: _uniqueSorted(
          group.expand((option) => option.evidence.sourceDeviationIds),
        ),
        sourceModelIds: _uniqueSorted(
          group.expand((option) => option.evidence.sourceModelIds),
        ),
      ),
      metadata: FinancialDecisionOptionMetadata(
        generatedAt: generatedAt,
        engineVersion: first.metadata.engineVersion,
        ruleId: first.metadata.ruleId,
      ),
      effectHorizon: first.effectHorizon,
    );
  }

  List<String> _uniqueSorted(Iterable<String> values) {
    return List.unmodifiable(values.toSet().toList()..sort());
  }

  List<FinancialDecisionObjective> _uniqueObjectives(
    Iterable<FinancialDecisionObjective> objectives,
  ) {
    final byId = <String, FinancialDecisionObjective>{};
    for (final objective in objectives) {
      byId[objective.objectiveId] = objective;
    }
    return List.unmodifiable(
      byId.values.toList()
        ..sort((a, b) => a.objectiveId.compareTo(b.objectiveId)),
    );
  }

  FinancialDecisionOptionStatus _leastAvailableStatus(
    Iterable<FinancialDecisionOptionStatus> statuses,
  ) {
    if (statuses.contains(FinancialDecisionOptionStatus.futureUnavailable)) {
      return FinancialDecisionOptionStatus.futureUnavailable;
    }
    if (statuses.contains(FinancialDecisionOptionStatus.unavailable)) {
      return FinancialDecisionOptionStatus.unavailable;
    }
    if (statuses.contains(FinancialDecisionOptionStatus.conditional)) {
      return FinancialDecisionOptionStatus.conditional;
    }
    return FinancialDecisionOptionStatus.available;
  }

  FinancialDecisionOptionApplicability _leastAvailableApplicability(
    Iterable<FinancialDecisionOptionApplicability> applicabilities,
  ) {
    if (applicabilities.contains(
      FinancialDecisionOptionApplicability.futureUnavailable,
    )) {
      return FinancialDecisionOptionApplicability.futureUnavailable;
    }
    if (applicabilities.contains(
      FinancialDecisionOptionApplicability.notApplicable,
    )) {
      return FinancialDecisionOptionApplicability.notApplicable;
    }
    if (applicabilities.contains(
      FinancialDecisionOptionApplicability.conditional,
    )) {
      return FinancialDecisionOptionApplicability.conditional;
    }
    return FinancialDecisionOptionApplicability.applicable;
  }
}
