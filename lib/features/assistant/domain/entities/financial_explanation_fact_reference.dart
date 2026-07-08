import 'financial_fact_confidence.dart';
import 'financial_fact_type.dart';

final class FinancialExplanationFactReference {
  FinancialExplanationFactReference({
    required this.factId,
    required this.factType,
    required this.confidence,
    Map<String, String> metadata = const {},
  }) : metadata = Map.unmodifiable(metadata);

  final String factId;
  final FinancialFactType factType;
  final FinancialFactConfidence confidence;
  final Map<String, String> metadata;
}
