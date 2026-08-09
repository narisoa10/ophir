import '../../../../core/icons/app_account_icons.dart';
import '../../domain/entities/account.dart';
import '../models/account_presentation.dart';

final class AccountAdapter {
  const AccountAdapter();

  AccountPresentation toPresentation(Account account) {
    final iconKey = account.iconKey;

    return AccountPresentation(
      name: account.name,
      icon: iconKey == null ? null : AppAccountIcons.fromKey(iconKey),
      colorKey: account.colorKey,
    );
  }
}
