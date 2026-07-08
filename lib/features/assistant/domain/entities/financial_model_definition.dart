import 'financial_model_type.dart';
import 'financial_model_unit.dart';

final class FinancialModelDefinition {
  const FinancialModelDefinition({
    required this.id,
    required this.type,
    required this.unit,
  });

  final String id;
  final FinancialModelType type;
  final FinancialModelUnit unit;
}
