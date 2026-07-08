import '../enums/category_stable_key.dart';
import '../enums/category_type.dart';
import '../enums/financial_action_semantics.dart';
import '../enums/financial_impact.dart';
import '../enums/spending_pattern.dart';
import '../enums/spending_role.dart';

final class CategoryIntelligenceProfile {
  const CategoryIntelligenceProfile({
    required this.stableKey,
    required this.type,
    required this.spendingRole,
    required this.spendingPattern,
    required this.financialImpact,
    required this.financialActionSemantics,
  });

  final CategoryStableKey stableKey;
  final CategoryType type;
  final SpendingRole spendingRole;
  final SpendingPattern spendingPattern;
  final FinancialImpact financialImpact;
  final FinancialActionSemantics financialActionSemantics;

  bool get isOrdinarySpending {
    return financialImpact == FinancialImpact.ordinaryExpense;
  }
}
