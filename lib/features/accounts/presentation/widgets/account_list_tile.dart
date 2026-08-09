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
    this.balance,
    this.currencyCode,
    this.subtitle,
    super.key,
  });

  final AccountPresentation account;
  final double? balance;
  final String? currencyCode;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    final colors = context.appThemeColors;
    final leading = _buildLeading(colors);
    final trailing = _buildTrailing(colors);

    return ListTile(
      dense: true,
      visualDensity: VisualDensity.compact,
      contentPadding: AppSpacing.compactListTileInsets,
      leading: leading,
      title: Text(
        account.name,
        style: AppTypography.bodyMd.copyWith(color: colors.textPrimary),
      ),
      subtitle: subtitle == null
          ? null
          : Text(
              subtitle!,
              style: AppTypography.bodySm.copyWith(color: colors.textSecondary),
            ),
      trailing: trailing,
    );
  }

  Widget? _buildLeading(AppThemeColors colors) {
    final icon = account.icon;
    final colorKey = account.colorKey;

    if (icon == null || colorKey == null) {
      return null;
    }

    final accountColor = AppCategoryColors.fromKey(colors, colorKey);
    final accountBackgroundColor = AppCategoryColors.backgroundFromKey(
      colors,
      colorKey,
    );

    return Container(
      width: AppDimensions.avatarMd,
      height: AppDimensions.avatarMd,
      decoration: BoxDecoration(
        color: accountBackgroundColor,
        shape: BoxShape.circle,
      ),
      child: Icon(icon, color: accountColor, size: AppDimensions.iconMd),
    );
  }

  Widget? _buildTrailing(AppThemeColors colors) {
    final displayBalance = balance;
    if (displayBalance == null) {
      return null;
    }

    final currency = currencyCode;
    final text = currency == null
        ? displayBalance.toStringAsFixed(2)
        : '${displayBalance.toStringAsFixed(2)} $currency';

    return Text(
      text,
      style: AppTypography.bodyMd.copyWith(color: colors.textPrimary),
    );
  }
}
