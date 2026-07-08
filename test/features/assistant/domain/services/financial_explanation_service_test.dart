import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:ophir/features/assistant/domain/entities/financial_decision_expected_model_change.dart';
import 'package:ophir/features/assistant/domain/entities/financial_decision_objective.dart';
import 'package:ophir/features/assistant/domain/entities/financial_decision_objective_type.dart';
import 'package:ophir/features/assistant/domain/entities/financial_decision_option.dart';
import 'package:ophir/features/assistant/domain/entities/financial_decision_option_applicability.dart';
import 'package:ophir/features/assistant/domain/entities/financial_decision_option_availability_reason.dart';
import 'package:ophir/features/assistant/domain/entities/financial_decision_option_condition.dart';
import 'package:ophir/features/assistant/domain/entities/financial_decision_option_cost.dart';
import 'package:ophir/features/assistant/domain/entities/financial_decision_option_cost_level.dart';
import 'package:ophir/features/assistant/domain/entities/financial_decision_option_effect_horizon.dart';
import 'package:ophir/features/assistant/domain/entities/financial_decision_option_evidence.dart';
import 'package:ophir/features/assistant/domain/entities/financial_decision_option_impact.dart';
import 'package:ophir/features/assistant/domain/entities/financial_decision_option_limitation.dart';
import 'package:ophir/features/assistant/domain/entities/financial_decision_option_metadata.dart';
import 'package:ophir/features/assistant/domain/entities/financial_decision_option_risk.dart';
import 'package:ophir/features/assistant/domain/entities/financial_decision_option_risk_level.dart';
import 'package:ophir/features/assistant/domain/entities/financial_decision_option_status.dart';
import 'package:ophir/features/assistant/domain/entities/financial_decision_option_type.dart';
import 'package:ophir/features/assistant/domain/entities/financial_decision_target.dart';
import 'package:ophir/features/assistant/domain/entities/financial_decision_target_direction.dart';
import 'package:ophir/features/assistant/domain/entities/financial_deviation.dart';
import 'package:ophir/features/assistant/domain/entities/financial_deviation_confidence.dart';
import 'package:ophir/features/assistant/domain/entities/financial_deviation_evidence.dart';
import 'package:ophir/features/assistant/domain/entities/financial_deviation_expected_value.dart';
import 'package:ophir/features/assistant/domain/entities/financial_deviation_limitation.dart';
import 'package:ophir/features/assistant/domain/entities/financial_deviation_metadata.dart';
import 'package:ophir/features/assistant/domain/entities/financial_deviation_severity.dart';
import 'package:ophir/features/assistant/domain/entities/financial_deviation_status.dart';
import 'package:ophir/features/assistant/domain/entities/financial_deviation_type.dart';
import 'package:ophir/features/assistant/domain/entities/financial_explanation_confidence.dart';
import 'package:ophir/features/assistant/domain/entities/financial_explanation_edge.dart';
import 'package:ophir/features/assistant/domain/entities/financial_explanation_edge_type.dart';
import 'package:ophir/features/assistant/domain/entities/financial_explanation_fact_reference.dart';
import 'package:ophir/features/assistant/domain/entities/financial_explanation_graph.dart';
import 'package:ophir/features/assistant/domain/entities/financial_explanation_node.dart';
import 'package:ophir/features/assistant/domain/entities/financial_explanation_node_type.dart';
import 'package:ophir/features/assistant/domain/entities/financial_explanation_reference_index.dart';
import 'package:ophir/features/assistant/domain/entities/financial_explanation_reference_type.dart';
import 'package:ophir/features/assistant/domain/entities/financial_explanation_source_layer.dart';
import 'package:ophir/features/assistant/domain/entities/financial_explanation_status.dart';
import 'package:ophir/features/assistant/domain/entities/financial_explanation_validation_issue_type.dart';
import 'package:ophir/features/assistant/domain/entities/financial_fact_confidence.dart';
import 'package:ophir/features/assistant/domain/entities/financial_fact_type.dart';
import 'package:ophir/features/assistant/domain/entities/financial_model_confidence.dart';
import 'package:ophir/features/assistant/domain/entities/financial_model_evidence.dart';
import 'package:ophir/features/assistant/domain/entities/financial_model_limitation.dart';
import 'package:ophir/features/assistant/domain/entities/financial_model_metadata.dart';
import 'package:ophir/features/assistant/domain/entities/financial_model_period.dart';
import 'package:ophir/features/assistant/domain/entities/financial_model_result.dart';
import 'package:ophir/features/assistant/domain/entities/financial_model_status.dart';
import 'package:ophir/features/assistant/domain/entities/financial_model_type.dart';
import 'package:ophir/features/assistant/domain/entities/financial_model_unit.dart';
import 'package:ophir/features/assistant/domain/entities/financial_problem.dart';
import 'package:ophir/features/assistant/domain/entities/financial_problem_confidence.dart';
import 'package:ophir/features/assistant/domain/entities/financial_problem_evidence.dart';
import 'package:ophir/features/assistant/domain/entities/financial_problem_impact.dart';
import 'package:ophir/features/assistant/domain/entities/financial_problem_limitation.dart';
import 'package:ophir/features/assistant/domain/entities/financial_problem_metadata.dart';
import 'package:ophir/features/assistant/domain/entities/financial_problem_severity.dart';
import 'package:ophir/features/assistant/domain/entities/financial_problem_signal.dart';
import 'package:ophir/features/assistant/domain/entities/financial_problem_status.dart';
import 'package:ophir/features/assistant/domain/entities/financial_problem_type.dart';
import 'package:ophir/features/assistant/domain/entities/financial_rejected_alternative_reason.dart';
import 'package:ophir/features/assistant/domain/entities/financial_recommendation.dart';
import 'package:ophir/features/assistant/domain/services/financial_explanation_service.dart';
import 'package:ophir/features/assistant/domain/services/financial_explanation_validation_service.dart';
import 'package:ophir/features/assistant/domain/services/financial_recommendation_service.dart';

final _generatedAt = DateTime(2026, 4);
final _period = FinancialModelPeriod(
  start: DateTime(2026, 3),
  end: DateTime(2026, 4),
);
final _recommendationService = FinancialRecommendationService(
  generatedAt: _generatedAt,
);
final _service = FinancialExplanationService(generatedAt: _generatedAt);

void main() {
  group('FinancialExplanationService', () {
    test('builds graph for selected recommendation', () {
      final recommendation = _recommendation();
      final explanation = _service.explain(recommendation, _referenceIndex());

      expect(explanation.status, FinancialExplanationStatus.complete);
      expect(explanation.graph.rootNodeId, 'recommendation.recommendation-1');
      expect(
        _node(
          explanation.graph.nodes,
          FinancialExplanationNodeType.recommendation,
        ).referencedEntityIds,
        ['recommendation-1'],
      );
    });

    test('graph contains recommendation to selected option edge', () {
      final explanation = _service.explain(
        _recommendation(),
        _referenceIndex(),
      );

      expect(
        explanation.graph.edges.any(
          (edge) =>
              edge.edgeType == FinancialExplanationEdgeType.selected &&
              edge.fromNodeId == 'recommendation.recommendation-1' &&
              edge.toNodeId == 'selectedOption.option.selected',
        ),
        isTrue,
      );
    });

    test('graph contains rejected alternatives', () {
      final explanation = _service.explain(
        _recommendation(),
        _referenceIndex(),
      );

      final rejected = _node(
        explanation.graph.nodes,
        FinancialExplanationNodeType.rejectedAlternative,
      );

      expect(rejected.referencedEntityIds, contains('option.rejected'));
      expect(
        rejected.referencedEntityIds,
        contains(FinancialRejectedAlternativeReason.lowerExpectedImpact.name),
      );
    });

    test('selected option links to problems through option evidence', () {
      final explanation = _service.explain(
        _recommendation(),
        _referenceIndex(),
      );

      expect(
        explanation.graph.edges.any(
          (edge) =>
              edge.fromNodeId == 'selectedOption.option.selected' &&
              edge.toNodeId == 'problem.problem.expense',
        ),
        isTrue,
      );
    });

    test(
      'problems link to deviations and model ids through problem evidence',
      () {
        final explanation = _service.explain(
          _recommendation(),
          _referenceIndex(),
        );

        expect(
          explanation.graph.edges.any(
            (edge) =>
                edge.fromNodeId == 'problem.problem.expense' &&
                edge.toNodeId == 'deviation.deviation.expense',
          ),
          isTrue,
        );
        expect(
          explanation.graph.edges.any(
            (edge) =>
                edge.fromNodeId == 'problem.problem.expense' &&
                edge.toNodeId == 'model.model.expense',
          ),
          isTrue,
        );
      },
    );

    test('deviations link to models and facts through deviation evidence', () {
      final explanation = _service.explain(
        _recommendation(),
        _referenceIndex(),
      );

      expect(
        explanation.graph.edges.any(
          (edge) =>
              edge.fromNodeId == 'deviation.deviation.expense' &&
              edge.toNodeId == 'model.model.expense',
        ),
        isTrue,
      );
      expect(
        explanation.graph.edges.any(
          (edge) =>
              edge.fromNodeId == 'deviation.deviation.expense' &&
              edge.toNodeId == 'fact.fact.expense',
        ),
        isTrue,
      );
    });

    test('model results link to fact ids through model evidence', () {
      final explanation = _service.explain(
        _recommendation(),
        _referenceIndex(),
      );

      expect(
        explanation.graph.edges.any(
          (edge) =>
              edge.fromNodeId == 'model.model.expense' &&
              edge.toNodeId == 'fact.fact.expense',
        ),
        isTrue,
      );
    });

    test('missing reference creates validation issue', () {
      final explanation = _service.explain(
        _recommendation(),
        _referenceIndex(problems: const []),
      );

      expect(explanation.status, FinancialExplanationStatus.incomplete);
      expect(
        explanation.validationIssues.any(
          (issue) =>
              issue.issueType ==
                  FinancialExplanationValidationIssueType.missingReference &&
              issue.referenceId == 'problem.expense',
        ),
        isTrue,
      );
    });

    test('missing fact reference creates validation issue', () {
      final explanation = _service.explain(
        _recommendation(),
        _referenceIndex(facts: const []),
      );

      expect(explanation.status, FinancialExplanationStatus.incomplete);
      expect(
        explanation.validationIssues.any(
          (issue) =>
              issue.issueType ==
                  FinancialExplanationValidationIssueType.missingReference &&
              issue.referenceId == 'fact.expense',
        ),
        isTrue,
      );
    });

    test('missing rejected option creates validation issue', () {
      final explanation = _service.explain(
        _recommendation(),
        _referenceIndex(options: [_selectedOption()]),
      );

      expect(explanation.status, FinancialExplanationStatus.incomplete);
      expect(
        explanation.validationIssues.any(
          (issue) =>
              issue.issueType ==
                  FinancialExplanationValidationIssueType.missingReference &&
              issue.referenceId == 'option.rejected',
        ),
        isTrue,
      );
    });

    test('graph has no cycles', () {
      final explanation = _service.explain(
        _recommendation(),
        _referenceIndex(),
      );

      expect(
        explanation.validationIssues.where(
          (issue) =>
              issue.issueType ==
              FinancialExplanationValidationIssueType.cycleDetected,
        ),
        isEmpty,
      );
    });

    test('validation service reports cyclic graph', () {
      const validationService = FinancialExplanationValidationService();
      const graph = FinancialExplanationGraph(
        rootNodeId: 'recommendation.rec',
        nodes: [
          FinancialExplanationNode(
            id: 'recommendation.rec',
            nodeType: FinancialExplanationNodeType.recommendation,
            sourceLayer: FinancialExplanationSourceLayer.recommendation,
            referencedEntityIds: ['rec'],
            confidence: FinancialExplanationConfidence.high,
            evidence: [],
            assumptions: [],
            limitations: [],
            children: ['selectedOption.opt'],
            parents: ['selectedOption.opt'],
          ),
          FinancialExplanationNode(
            id: 'selectedOption.opt',
            nodeType: FinancialExplanationNodeType.selectedOption,
            sourceLayer: FinancialExplanationSourceLayer.decisionOption,
            referencedEntityIds: ['opt'],
            confidence: FinancialExplanationConfidence.high,
            evidence: [],
            assumptions: [],
            limitations: [],
            children: ['recommendation.rec'],
            parents: ['recommendation.rec'],
          ),
        ],
        edges: [
          FinancialExplanationEdge(
            id: 'recommendation.rec.selected.selectedOption.opt',
            fromNodeId: 'recommendation.rec',
            toNodeId: 'selectedOption.opt',
            edgeType: FinancialExplanationEdgeType.selected,
          ),
          FinancialExplanationEdge(
            id: 'selectedOption.opt.supportedBy.recommendation.rec',
            fromNodeId: 'selectedOption.opt',
            toNodeId: 'recommendation.rec',
            edgeType: FinancialExplanationEdgeType.supportedBy,
          ),
        ],
      );

      final issues = validationService.validate(graph);

      expect(
        issues.map((issue) => issue.issueType),
        contains(FinancialExplanationValidationIssueType.cycleDetected),
      );
    });

    test('references are typed', () {
      final explanation = _service.explain(
        _recommendation(),
        _referenceIndex(),
      );
      final selected = _node(
        explanation.graph.nodes,
        FinancialExplanationNodeType.selectedOption,
      );
      final references = selected.evidence.single.references;

      expect(
        references.map((reference) => reference.referenceType),
        contains(FinancialExplanationReferenceType.problem),
      );
      expect(
        references.map((reference) => reference.sourceLayer),
        contains(FinancialExplanationSourceLayer.problem),
      );
    });

    test('confidence is preserved', () {
      final explanation = _service.explain(
        _recommendation(),
        _referenceIndex(),
      );

      expect(explanation.confidence, FinancialExplanationConfidence.high);
      expect(
        _nodeById(
          explanation.graph.nodes,
          'problem.problem.expense',
        ).confidence,
        FinancialExplanationConfidence.low,
      );
      expect(
        _nodeById(explanation.graph.nodes, 'model.model.expense').confidence,
        FinancialExplanationConfidence.medium,
      );
    });

    test('evidence is preserved from source evidence only', () {
      final explanation = _service.explain(
        _recommendation(),
        _referenceIndex(),
      );
      final deviation = _nodeById(
        explanation.graph.nodes,
        'deviation.deviation.expense',
      );

      expect(deviation.evidence.single.sourceEntityId, 'deviation.expense');
      expect(
        deviation.evidence.single.references.map(
          (reference) => reference.referenceId,
        ),
        containsAll(['model.expense', 'fact.expense']),
      );
    });

    test('limitations and assumptions are preserved', () {
      final explanation = _service.explain(
        _recommendation(),
        _referenceIndex(),
      );

      final option = _node(
        explanation.graph.nodes,
        FinancialExplanationNodeType.selectedOption,
      );
      final model = _nodeById(explanation.graph.nodes, 'model.model.expense');

      expect(
        option.limitations.map((limitation) => limitation.limitationId),
        containsAll(['option.limit', 'condition.required']),
      );
      expect(
        model.limitations.map((limitation) => limitation.limitationId),
        contains(FinancialModelLimitation.insufficientHistory.name),
      );
      expect(
        model.assumptions.map((assumption) => assumption.assumptionId),
        contains('assumption.model.coverage'),
      );
    });

    test('explanation does not call lower-layer calculation services', () {
      final phase7Files = _phase7Files();
      final source = phase7Files
          .map((file) => file.readAsStringSync())
          .join('\n')
          .toLowerCase();

      expect(source, isNot(contains('financialfactsservice')));
      expect(source, isNot(contains('financialmodelsservice')));
      expect(source, isNot(contains('financialdeviationservice')));
      expect(source, isNot(contains('financialproblemdetectionservice')));
      expect(source, isNot(contains('financialdecisionoptionsservice')));
      expect(source, isNot(contains('financialrecommendationservice')));
    });

    test('explanation contains no user-facing prose markers', () {
      final bannedTokens = {
        'ai',
        'prompt',
        'markdown',
        'measurement',
        'measurementplan',
        'chat',
        'l10n',
        'dashboard',
        'forecast',
        'budget',
        'goal',
        'learning',
        'rationale',
        'copy',
        'text',
      };

      for (final file in _phase7Files()) {
        final source = file.readAsStringSync();
        final normalized = source.toLowerCase();
        expect(source, isNot(contains('DateTime.now')), reason: file.path);
        expect(normalized, isNot(contains('user-facing')), reason: file.path);
        expect(normalized, isNot(contains('user facing')), reason: file.path);
        expect(
          normalized,
          isNot(contains('natural-language')),
          reason: file.path,
        );
        expect(
          normalized,
          isNot(contains('natural language')),
          reason: file.path,
        );
        final strippedSource = normalized.replaceAll(
          'financial-explanations-v1',
          '',
        );
        final tokens = strippedSource.split(RegExp('[^a-z0-9-]+')).toSet();
        for (final token in bannedTokens) {
          expect(tokens, isNot(contains(token)), reason: file.path);
        }
      }
    });

    test('deterministic ordering is independent of input order', () {
      final recommendation = _recommendation();
      final first = _service.explain(recommendation, _referenceIndex());
      final second = _service.explain(
        recommendation,
        _referenceIndex(
          options: [_rejectedOption(), _selectedOption()],
          problems: [_rejectedProblem(), _selectedProblem()],
          deviations: [_rejectedDeviation(), _selectedDeviation()],
          modelResults: [_rejectedModel(), _selectedModel()],
          facts: [_rejectedFact(), _selectedFact()],
        ),
      );

      expect(
        second.graph.nodes.map((node) => node.id),
        first.graph.nodes.map((node) => node.id),
      );
      expect(
        second.graph.edges.map((edge) => edge.id),
        first.graph.edges.map((edge) => edge.id),
      );
    });

    test(
      'same recommendation and same reference index produce same explanation',
      () {
        final recommendation = _recommendation();
        final index = _referenceIndex();
        final first = _service.explain(recommendation, index);
        final second = _service.explain(recommendation, index);

        expect(second.explanationId, first.explanationId);
        expect(second.steps.single.nodeIds, first.steps.single.nodeIds);
        expect(
          second.graph.edges.map((edge) => edge.id),
          first.graph.edges.map((edge) => edge.id),
        );
      },
    );

    test('rejected alternatives preserve their own evidence', () {
      final explanation = _service.explain(
        _recommendation(),
        _referenceIndex(),
      );
      final rejected = _node(
        explanation.graph.nodes,
        FinancialExplanationNodeType.rejectedAlternative,
      );

      expect(rejected.evidence.single.sourceEntityId, 'option.rejected');
      expect(
        rejected.evidence.single.references.map(
          (reference) => reference.referenceId,
        ),
        containsAll([
          'problem.rejected',
          'deviation.rejected',
          'model.rejected',
        ]),
      );
    });

    test('graph contains no direct recommendation to fact edge', () {
      final explanation = _service.explain(
        _recommendation(),
        _referenceIndex(),
      );

      expect(
        explanation.graph.edges.where(
          (edge) =>
              edge.fromNodeId.startsWith('recommendation.') &&
              edge.toNodeId.startsWith('fact.'),
        ),
        isEmpty,
      );
    });

    test('reference index and resolver do not expose raw fact source ids', () {
      final indexSource = File(
        'lib/features/assistant/domain/entities/'
        'financial_explanation_reference_index.dart',
      ).readAsStringSync();
      final resolverSource = File(
        'lib/features/assistant/domain/services/'
        'financial_explanation_reference_resolver.dart',
      ).readAsStringSync();

      for (final source in [indexSource, resolverSource]) {
        expect(source, isNot(contains('FinancialFact')));
        expect(source, isNot(contains('operationId')));
        expect(source, isNot(contains('categoryId')));
        expect(source, isNot(contains('accountId')));
      }
    });

    test('phase 7 files do not import raw source or presentation concepts', () {
      final forbiddenImportTokens = [
        'operation',
        'operationid',
        'category',
        'categoryid',
        'account',
        'accountid',
        'dashboard',
        '/ui/',
        '\\ui\\',
      ];

      for (final file in _phase7Files()) {
        final importLines = file.readAsLinesSync().where(
          (line) => line.trimLeft().startsWith('import '),
        );
        for (final line in importLines) {
          final normalized = line.toLowerCase();
          for (final token in forbiddenImportTokens) {
            expect(normalized, isNot(contains(token)), reason: file.path);
          }
        }
      }
    });
  });
}

List<File> _phase7Files() {
  return Directory('lib/features/assistant')
      .listSync(recursive: true)
      .whereType<File>()
      .where(
        (file) =>
            file.uri.pathSegments.last.startsWith('financial_explanation'),
      )
      .toList(growable: false);
}

FinancialExplanationReferenceIndex _referenceIndex({
  List<FinancialDecisionOption>? options,
  List<FinancialProblem>? problems,
  List<FinancialDeviation>? deviations,
  List<FinancialModelResult>? modelResults,
  List<FinancialExplanationFactReference>? facts,
}) {
  return FinancialExplanationReferenceIndex(
    options: options ?? [_selectedOption(), _rejectedOption()],
    problems: problems ?? [_selectedProblem(), _rejectedProblem()],
    deviations: deviations ?? [_selectedDeviation(), _rejectedDeviation()],
    modelResults: modelResults ?? [_selectedModel(), _rejectedModel()],
    facts: facts ?? [_selectedFact(), _rejectedFact()],
  );
}

FinancialExplanationNode _node(
  List<FinancialExplanationNode> nodes,
  FinancialExplanationNodeType type,
) {
  return nodes.singleWhere((node) => node.nodeType == type);
}

FinancialExplanationNode _nodeById(
  List<FinancialExplanationNode> nodes,
  String id,
) {
  return nodes.singleWhere((node) => node.id == id);
}

FinancialRecommendation _recommendation() {
  final recommendation = _recommendationService.recommend([
    _selectedOption(),
    _rejectedOption(),
  ])!;
  return FinancialRecommendation(
    recommendationId: 'recommendation-1',
    selectedOption: recommendation.selectedOption,
    selectedOptionId: recommendation.selectedOptionId,
    selectedOptionType: recommendation.selectedOptionType,
    status: recommendation.status,
    priority: recommendation.priority,
    confidence: recommendation.confidence,
    evaluation: recommendation.evaluation,
    rejectedAlternatives: recommendation.rejectedAlternatives,
    evidence: recommendation.evidence,
    metadata: recommendation.metadata,
  );
}

FinancialDecisionOption _selectedOption() {
  return _option(
    id: 'option.selected',
    type: FinancialDecisionOptionType.reviewExpenseStructure,
    problemId: 'problem.expense',
    deviationId: 'deviation.expense',
    modelId: 'model.expense',
    factId: 'fact.expense',
    expectedModelChangeCount: 2,
  );
}

FinancialDecisionOption _rejectedOption() {
  return _option(
    id: 'option.rejected',
    type: FinancialDecisionOptionType.reviewLargeExpense,
    problemId: 'problem.rejected',
    deviationId: 'deviation.rejected',
    modelId: 'model.rejected',
    factId: 'fact.rejected',
    expectedModelChangeCount: 1,
  );
}

FinancialDecisionOption _option({
  required String id,
  required FinancialDecisionOptionType type,
  required String problemId,
  required String deviationId,
  required String modelId,
  required String factId,
  required int expectedModelChangeCount,
}) {
  return FinancialDecisionOption(
    optionId: id,
    optionType: type,
    status: FinancialDecisionOptionStatus.available,
    applicability: FinancialDecisionOptionApplicability.applicable,
    linkedProblemIds: [problemId],
    solvesProblemTypes: const [FinancialProblemType.expensePressure],
    mayWorsenProblemTypes: const [],
    objectives: [
      FinancialDecisionObjective(
        objectiveId: 'objective.$id',
        objectiveType: FinancialDecisionObjectiveType.reduceExpensePressure,
        sourceProblemId: problemId,
        sourceProblemType: FinancialProblemType.expensePressure,
      ),
    ],
    targets: const [
      FinancialDecisionTarget(
        targetModelType: FinancialModelType.expenseToIncomeRatio,
        desiredDirection: FinancialDecisionTargetDirection.decrease,
        expectedImprovement: null,
        unit: FinancialModelUnit.percentage,
        confidence: FinancialProblemConfidence.high,
      ),
    ],
    expectedModelChanges: [
      for (var index = 0; index < expectedModelChangeCount; index++)
        const FinancialDecisionExpectedModelChange(
          modelType: FinancialModelType.expenseToIncomeRatio,
          direction: FinancialDecisionTargetDirection.decrease,
          expectedChange: null,
          unit: FinancialModelUnit.percentage,
          confidence: FinancialProblemConfidence.high,
        ),
    ],
    impact: const FinancialDecisionOptionImpact(
      isQuantitative: false,
      effectHorizon: FinancialDecisionOptionEffectHorizon.immediate,
    ),
    cost: const FinancialDecisionOptionCost(
      effort: FinancialDecisionOptionCostLevel.low,
      timeCost: FinancialDecisionOptionCostLevel.low,
      financialCost: FinancialDecisionOptionCostLevel.none,
    ),
    risk: const FinancialDecisionOptionRisk(
      level: FinancialDecisionOptionRiskLevel.low,
      mayWorsenProblemTypes: [],
    ),
    conditions: const [
      FinancialDecisionOptionCondition(
        conditionId: 'condition.required',
        isRequired: true,
      ),
    ],
    limitations: const [
      FinancialDecisionOptionLimitation(limitationId: 'option.limit'),
    ],
    availabilityReasons: const <FinancialDecisionOptionAvailabilityReason>[],
    evidence: FinancialDecisionOptionEvidence(
      sourceProblemIds: [problemId],
      sourceProblemTypes: const [FinancialProblemType.expensePressure],
      sourceDeviationIds: [deviationId],
      sourceModelIds: [modelId],
    ),
    metadata: FinancialDecisionOptionMetadata(
      generatedAt: _generatedAt,
      engineVersion: 'test-options',
      ruleId: 'rule.$id.$factId',
    ),
    effectHorizon: FinancialDecisionOptionEffectHorizon.immediate,
  );
}

FinancialProblem _selectedProblem() {
  return _problem(
    id: 'problem.expense',
    deviationId: 'deviation.expense',
    modelId: 'model.expense',
  );
}

FinancialProblem _rejectedProblem() {
  return _problem(
    id: 'problem.rejected',
    deviationId: 'deviation.rejected',
    modelId: 'model.rejected',
  );
}

FinancialProblem _problem({
  required String id,
  required String deviationId,
  required String modelId,
}) {
  return FinancialProblem(
    problemId: id,
    problemType: FinancialProblemType.expensePressure,
    status: FinancialProblemStatus.detected,
    severity: FinancialProblemSeverity.medium,
    confidence: FinancialProblemConfidence.low,
    impact: FinancialProblemImpact.cashFlow,
    period: _period,
    signals: [
      FinancialProblemSignal(
        deviationId: deviationId,
        deviationType: FinancialDeviationType.highExpenseToIncomeRatio,
        severity: FinancialDeviationSeverity.medium,
        confidence: FinancialDeviationConfidence.low,
        isPrimary: true,
      ),
    ],
    evidence: FinancialProblemEvidence(
      sourceDeviationIds: [deviationId],
      sourceDeviationTypes: const [
        FinancialDeviationType.highExpenseToIncomeRatio,
      ],
      sourceModelIds: [modelId],
    ),
    limitations: const [FinancialProblemLimitation.lowSourceConfidence],
    metadata: FinancialProblemMetadata(
      calculatedAt: _generatedAt,
      engineVersion: 'test-problems',
      ruleId: 'rule.$id',
    ),
  );
}

FinancialDeviation _selectedDeviation() {
  return _deviation(
    id: 'deviation.expense',
    modelId: 'model.expense',
    factId: 'fact.expense',
  );
}

FinancialDeviation _rejectedDeviation() {
  return _deviation(
    id: 'deviation.rejected',
    modelId: 'model.rejected',
    factId: 'fact.rejected',
  );
}

FinancialDeviation _deviation({
  required String id,
  required String modelId,
  required String factId,
}) {
  return FinancialDeviation(
    deviationId: id,
    deviationType: FinancialDeviationType.highExpenseToIncomeRatio,
    status: FinancialDeviationStatus.calculated,
    severity: FinancialDeviationSeverity.medium,
    actualValue: 0.6,
    expectedValue: const FinancialDeviationExpectedValue(
      thresholdValue: 0.4,
      unit: FinancialModelUnit.percentage,
      isUpperBound: true,
    ),
    deviationAmount: 0.2,
    unit: FinancialModelUnit.percentage,
    period: _period,
    confidence: FinancialDeviationConfidence.medium,
    evidence: FinancialDeviationEvidence(
      sourceModelIds: [modelId],
      sourceModelEvidenceFactIds: [factId],
    ),
    limitations: const [FinancialDeviationLimitation.lowSourceConfidence],
    metadata: FinancialDeviationMetadata(
      calculatedAt: _generatedAt,
      engineVersion: 'test-deviations',
      thresholdId: 'threshold.$id',
    ),
  );
}

FinancialModelResult _selectedModel() {
  return _model(id: 'model.expense', factId: 'fact.expense');
}

FinancialModelResult _rejectedModel() {
  return _model(id: 'model.rejected', factId: 'fact.rejected');
}

FinancialModelResult _model({required String id, required String factId}) {
  return FinancialModelResult(
    modelId: id,
    modelType: FinancialModelType.expenseToIncomeRatio,
    status: FinancialModelStatus.calculated,
    value: 0.6,
    unit: FinancialModelUnit.percentage,
    period: _period,
    currencyCode: null,
    dataConfidence: FinancialModelConfidence.medium,
    modelConfidence: FinancialModelConfidence.medium,
    evidence: FinancialModelEvidence(
      factIds: [factId],
      dataGapSourceIds: const [],
    ),
    assumptions: const ['assumption.model.coverage'],
    limitations: const [FinancialModelLimitation.insufficientHistory],
    inputCoverage: 0.8,
    metadata: FinancialModelMetadata(
      calculatedAt: _generatedAt,
      engineVersion: 'test-models',
      snapshotVersion: 'snapshot.$id',
    ),
    breakdown: const [],
  );
}

FinancialExplanationFactReference _selectedFact() => _fact('fact.expense');

FinancialExplanationFactReference _rejectedFact() => _fact('fact.rejected');

FinancialExplanationFactReference _fact(String id) {
  return FinancialExplanationFactReference(
    factId: id,
    factType: FinancialFactType.expenseOperation,
    confidence: FinancialFactConfidence.high,
  );
}
