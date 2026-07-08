import 'financial_behavior_fact.dart';
import 'financial_behavior_fact_kind.dart';

final class FinancialBehaviorFactsSnapshot {
  FinancialBehaviorFactsSnapshot({required List<FinancialBehaviorFact> facts})
    : facts = List.unmodifiable(facts);

  final List<FinancialBehaviorFact> facts;

  int get unresolvedCount {
    return facts
        .where((fact) => fact.kind == FinancialBehaviorFactKind.unresolved)
        .length;
  }

  List<FinancialBehaviorFact> get resolvedFacts {
    return facts.where((fact) => fact.isResolved).toList(growable: false);
  }

  List<FinancialBehaviorFact> get unresolvedFacts {
    return facts.where((fact) => !fact.isResolved).toList(growable: false);
  }
}
