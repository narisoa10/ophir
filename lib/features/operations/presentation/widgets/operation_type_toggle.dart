import 'package:flutter/material.dart';

import '../../../../core/theme_v1/app_colors.dart';
import '../../../../core/theme_v1/app_typography.dart';

class OperationTypeToggle extends StatelessWidget {
  const OperationTypeToggle({
    required this.isExpense,
    required this.expenseLabel,
    required this.incomeLabel,
    required this.onExpenseSelected,
    required this.onIncomeSelected,
    super.key,
  });

  final bool isExpense;
  final String expenseLabel;
  final String incomeLabel;
  final VoidCallback onExpenseSelected;
  final VoidCallback onIncomeSelected;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: TextButton(
            onPressed: onExpenseSelected,
            child: Text(expenseLabel, style: _style(isSelected: isExpense)),
          ),
        ),
        Expanded(
          child: TextButton(
            onPressed: onIncomeSelected,
            child: Text(incomeLabel, style: _style(isSelected: !isExpense)),
          ),
        ),
      ],
    );
  }

  TextStyle _style({required bool isSelected}) {
    return AppTypography.button.copyWith(
      color: isSelected ? AppColors.primary : AppColors.textSecondary,
    );
  }
}
