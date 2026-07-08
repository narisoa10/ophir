import 'financial_model_period.dart';
import 'financial_problem_confidence.dart';
import 'financial_problem_evidence.dart';
import 'financial_problem_impact.dart';
import 'financial_problem_limitation.dart';
import 'financial_problem_metadata.dart';
import 'financial_problem_severity.dart';
import 'financial_problem_signal.dart';
import 'financial_problem_status.dart';
import 'financial_problem_type.dart';

final class FinancialProblem {
  const FinancialProblem({
    required this.problemId,
    required this.problemType,
    required this.status,
    required this.severity,
    required this.confidence,
    required this.impact,
    required this.period,
    required this.signals,
    required this.evidence,
    required this.limitations,
    required this.metadata,
  });

  final String problemId;
  final FinancialProblemType problemType;
  final FinancialProblemStatus status;
  final FinancialProblemSeverity severity;
  final FinancialProblemConfidence confidence;
  final FinancialProblemImpact impact;
  final FinancialModelPeriod period;
  final List<FinancialProblemSignal> signals;
  final FinancialProblemEvidence evidence;
  final List<FinancialProblemLimitation> limitations;
  final FinancialProblemMetadata metadata;
}
