import 'financial_intelligence_model.dart';
import 'financial_intelligence_model_type.dart';

final class FinancialIntelligenceModelsSnapshot {
  FinancialIntelligenceModelsSnapshot({
    required List<FinancialIntelligenceModel> models,
  }) : models = List.unmodifiable(models);

  final List<FinancialIntelligenceModel> models;

  FinancialIntelligenceModel modelFor(FinancialIntelligenceModelType type) {
    return models.singleWhere((model) => model.type == type);
  }

  double valueFor(FinancialIntelligenceModelType type) {
    return modelFor(type).value;
  }
}
