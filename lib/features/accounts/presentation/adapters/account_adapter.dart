import '../../../../core/icons/app_account_icons.dart';
import '../../domain/entities/account.dart';
import '../models/account_presentation.dart';

final class AccountAdapter {
  const AccountAdapter();

  AccountPresentation toPresentation(Account account) {
    return AccountPresentation(
      name: account.name,
      icon: AppAccountIcons.fromKey(account.iconKey),
      colorKey: account.colorKey,
    );
  }
}
