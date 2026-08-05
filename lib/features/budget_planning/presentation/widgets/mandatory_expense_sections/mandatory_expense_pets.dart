import 'package:flutter/material.dart';

import '../../../../../core/categories/app_categories.dart';
import '../../../../../core/icons/app_category_icons.dart';
import '../../../../../core/localization/generated/app_localizations.dart';
import '../../../domain/entities/budget_obligation.dart';
import '../mandatory_expense_section.dart';

class MandatoryExpensePets extends StatelessWidget {
  const MandatoryExpensePets({
    required this.categories,
    required this.selectedCount,
    this.formattedAmount = '0.00 CAD',
    required this.isExpanded,
    required this.onToggle,
    required this.currencyCode,
    required this.obligationFor,
    required this.onCategoryTap,
    super.key,
  });

  final List<AppCategory> categories;
  final int selectedCount;
  final String formattedAmount;
  final bool isExpanded;
  final VoidCallback onToggle;
  final String currencyCode;
  final BudgetObligation? Function(AppCategory category) obligationFor;
  final ValueChanged<AppCategory> onCategoryTap;

  @override
  Widget build(BuildContext context) {
    return MandatoryExpenseSection(
      title: AppLocalizations.of(context).categoryGroupExpensePets,
      iconKey: AppCategoryIcons.petFood,
      categories: categories,
      selectedCount: selectedCount,
      formattedAmount: formattedAmount,
      isExpanded: isExpanded,
      onToggle: onToggle,
      currencyCode: currencyCode,
      obligationFor: obligationFor,
      onCategoryTap: onCategoryTap,
    );
  }
}
