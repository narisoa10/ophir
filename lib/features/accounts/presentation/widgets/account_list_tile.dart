import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../models/account_presentation.dart';

class AccountListTile extends StatelessWidget {
  const AccountListTile({
    required this.account,
    required this.initialBalance,
    required this.currencyCode,
    super.key,
  });

  final AccountPresentation account;
  final double initialBalance;
  final String currencyCode;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: AppSpacing.cardInsets,
      leading: Container(
        width: AppDimensions.avatarMd,
        height: AppDimensions.avatarMd,
        decoration: BoxDecoration(
          color: account.backgroundColor,
          shape: BoxShape.circle,
        ),
        child: Icon(
          account.icon,
          color: account.color,
          size: AppDimensions.iconMd,
        ),
      ),
      title: Text(
        account.name,
        style: AppTypography.bodyMd.copyWith(
          color: AppColors.textPrimary,
        ),
      ),
      trailing: Text(
        '${initialBalance.toStringAsFixed(2)} $currencyCode',
        style: AppTypography.bodyMd.copyWith(
          color: AppColors.textPrimary,
        ),
      ),
    );
  }
}