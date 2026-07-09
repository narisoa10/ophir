import '../../../categories/domain/entities/category.dart';
import '../../../operations/domain/entities/operation.dart';
import 'financial_model_period.dart';

final class FinancialIntelligenceDiagnosticsInput {
  FinancialIntelligenceDiagnosticsInput({
    required this.period,
    required this.incomeDenominator,
    required List<Operation> operations,
    required List<Category> categories,
  }) : operations = List.unmodifiable(operations),
       categories = List.unmodifiable(categories);

  final FinancialModelPeriod period;
  final double incomeDenominator;
  final List<Operation> operations;
  final List<Category> categories;
}
