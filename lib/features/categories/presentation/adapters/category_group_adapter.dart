import '../../../../core/localization/generated/app_localizations.dart';
import '../../domain/enums/category_ui_group.dart';

final class CategoryGroupAdapter {
  const CategoryGroupAdapter();

  String label(CategoryUiGroup group, AppLocalizations l10n) {
    final locale = l10n.localeName;

    if (locale.startsWith('ru')) {
      return switch (group) {
        CategoryUiGroup.housing => '\u0416\u0438\u043b\u044c\u0435',
        CategoryUiGroup.transport =>
          '\u0422\u0440\u0430\u043d\u0441\u043f\u043e\u0440\u0442',
        CategoryUiGroup.dailyLife =>
          '\u041f\u043e\u0432\u0441\u0435\u0434\u043d\u0435\u0432\u043d\u043e\u0435',
        CategoryUiGroup.outingsShopping =>
          '\u0412\u044b\u0445\u043e\u0434\u044b \u0438 \u043f\u043e\u043a\u0443\u043f\u043a\u0438',
        CategoryUiGroup.leisure => '\u0414\u043e\u0441\u0443\u0433',
        CategoryUiGroup.financeSavings =>
          '\u0424\u0438\u043d\u0430\u043d\u0441\u044b \u0438 \u043d\u0430\u043a\u043e\u043f\u043b\u0435\u043d\u0438\u044f',
        CategoryUiGroup.health =>
          '\u0417\u0434\u043e\u0440\u043e\u0432\u044c\u0435',
        CategoryUiGroup.development =>
          '\u0420\u0430\u0437\u0432\u0438\u0442\u0438\u0435',
        CategoryUiGroup.income => '\u0414\u043e\u0445\u043e\u0434\u044b',
      };
    }

    if (locale.startsWith('en')) {
      return switch (group) {
        CategoryUiGroup.housing => 'Housing',
        CategoryUiGroup.transport => 'Transport',
        CategoryUiGroup.dailyLife => 'Daily life',
        CategoryUiGroup.outingsShopping => 'Outings & shopping',
        CategoryUiGroup.leisure => 'Leisure',
        CategoryUiGroup.financeSavings => 'Finance & savings',
        CategoryUiGroup.health => 'Health',
        CategoryUiGroup.development => 'Development',
        CategoryUiGroup.income => 'Income',
      };
    }

    return switch (group) {
      CategoryUiGroup.housing => 'Logement',
      CategoryUiGroup.transport => 'Transport',
      CategoryUiGroup.dailyLife => 'Vie quotidienne',
      CategoryUiGroup.outingsShopping => 'Sorties & achats',
      CategoryUiGroup.leisure => 'Loisirs',
      CategoryUiGroup.financeSavings => 'Finance & \u00e9pargne',
      CategoryUiGroup.health => 'Sant\u00e9',
      CategoryUiGroup.development => 'D\u00e9veloppement',
      CategoryUiGroup.income => 'Revenus',
    };
  }
}
