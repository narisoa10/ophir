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
    final balanceText = _buildBalance(colors);

    // Identity lines and balance stack vertically so none of them competes
    // with the others for horizontal space; the mask must stay readable.
    final details = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          account.name,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: AppTypography.bodyMd.copyWith(color: colors.textPrimary),
        ),
        if (subtitle != null)
          Text(
            subtitle!,
            style: AppTypography.bodySm.copyWith(color: colors.textSecondary),
          ),
        if (balanceText != null) ...[
          const SizedBox(height: AppSpacing.xs),
          balanceText,
        ],
      ],
    );

    return Padding(
      padding: AppSpacing.compactListTileInsets,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (leading != null) ...[
            leading,
            const SizedBox(width: AppSpacing.md),
          ],
          Expanded(child: details),
        ],
      ),
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

  Widget? _buildBalance(AppThemeColors colors) {
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
