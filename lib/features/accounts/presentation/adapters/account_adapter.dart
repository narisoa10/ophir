import '../../../../core/icons/app_account_icons.dart';
import '../../../../core/theme/app_category_colors.dart';
import '../../domain/entities/account.dart';
import '../models/account_presentation.dart';

final class AccountAdapter {
  const AccountAdapter();

  AccountPresentation toPresentation(Account account) {
    return AccountPresentation(
      name: account.name,
      icon: AppAccountIcons.fromKey(account.iconKey),
      color: AppCategoryColors.fromKey(account.colorKey),
      backgroundColor: AppCategoryColors.backgroundFromKey(account.colorKey),
    );
  }
}