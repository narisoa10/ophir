import '../../../../core/icons/app_account_icons.dart';
import '../../../../core/theme_v1/app_category_colors.dart';
import '../enums/account_type.dart';

final class AccountVisualDefaults {
  const AccountVisualDefaults({required this.iconKey, required this.colorKey});

  final String iconKey;
  final String colorKey;

  factory AccountVisualDefaults.forType(AccountType type) {
    return switch (type) {
      AccountType.cash => const AccountVisualDefaults(
        iconKey: AppAccountIcons.cash,
        colorKey: AppCategoryColors.green,
      ),
      AccountType.bank => const AccountVisualDefaults(
        iconKey: AppAccountIcons.bank,
        colorKey: AppCategoryColors.blue,
      ),
      AccountType.card => const AccountVisualDefaults(
        iconKey: AppAccountIcons.card,
        colorKey: AppCategoryColors.purple,
      ),
      AccountType.creditCard => const AccountVisualDefaults(
        iconKey: AppAccountIcons.creditCard,
        colorKey: AppCategoryColors.red,
      ),
      AccountType.savings => const AccountVisualDefaults(
        iconKey: AppAccountIcons.savings,
        colorKey: AppCategoryColors.green,
      ),
      AccountType.investment => const AccountVisualDefaults(
        iconKey: AppAccountIcons.investment,
        colorKey: AppCategoryColors.orange,
      ),
      AccountType.loan => const AccountVisualDefaults(
        iconKey: AppAccountIcons.loan,
        colorKey: AppCategoryColors.red,
      ),
      AccountType.wallet => const AccountVisualDefaults(
        iconKey: AppAccountIcons.wallet,
        colorKey: AppCategoryColors.cyan,
      ),
      AccountType.other => const AccountVisualDefaults(
        iconKey: AppAccountIcons.other,
        colorKey: AppCategoryColors.gray,
      ),
    };
  }
}
