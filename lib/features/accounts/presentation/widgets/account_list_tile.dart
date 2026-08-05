import 'package:flutter/material.dart';

import '../../../../core/theme_v1/app_category_colors.dart';
import '../../../../core/theme_v1/app_theme_colors.dart';
import '../../../../core/theme_v1/app_dimensions.dart';
import '../../../../core/theme_v1/app_spacing.dart';
import '../../../../core/theme_v1/app_typography.dart';
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
    final colors = context.appThemeColors;
    final accountColor = AppCategoryColors.fromKey(colors, account.colorKey);
    final accountBackgroundColor = AppCategoryColors.backgroundFromKey(
      colors,
      account.colorKey,
    );

    return ListTile(
      contentPadding: AppSpacing.cardInsets,
      leading: Container(
        width: AppDimensions.avatarMd,
        height: AppDimensions.avatarMd,
        decoration: BoxDecoration(
          color: accountBackgroundColor,
          shape: BoxShape.circle,
        ),
        child: Icon(
          account.icon,
          color: accountColor,
          size: AppDimensions.iconMd,
        ),
      ),
      title: Text(
        account.name,
        style: AppTypography.bodyMd.copyWith(color: colors.textPrimary),
      ),
      trailing: Text(
        '${initialBalance.toStringAsFixed(2)} $currencyCode',
        style: AppTypography.bodyMd.copyWith(color: colors.textPrimary),
      ),
    );
  }
}
