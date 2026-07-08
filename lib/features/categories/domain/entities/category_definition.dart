import '../enums/category_stable_key.dart';
import '../enums/category_type.dart';
import '../enums/expense_category_group.dart';
import '../enums/income_category_group.dart';

final class CategoryDefinition {
  const CategoryDefinition({
    required this.key,
    required this.type,
    required this.sortOrder,
    required this.iconKey,
    required this.colorKey,
    this.expenseGroup,
    this.incomeGroup,
  }) : assert(
         (type == CategoryType.expense && expenseGroup != null) ||
             (type == CategoryType.income && incomeGroup != null),
       );

  final CategoryStableKey key;
  final CategoryType type;
  final ExpenseCategoryGroup? expenseGroup;
  final IncomeCategoryGroup? incomeGroup;
  final int sortOrder;
  final String iconKey;
  final String colorKey;

  String get stableKey => key.toJson();

  String get nameL10nKey {
    return 'categoryTaxonomy${_upperFirst(key.name)}Name';
  }

  String get exampleL10nKey {
    return 'categoryTaxonomy${_upperFirst(key.name)}Example';
  }

  String _upperFirst(String value) {
    return value[0].toUpperCase() + value.substring(1);
  }
}
