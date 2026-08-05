import '../../../../core/categories/app_categories.dart';
import '../../../../core/localization/generated/app_localizations.dart';
import '../../domain/entities/operation.dart';
import '../../domain/enums/operation_type.dart';

final class OperationDisplayLabels {
  const OperationDisplayLabels._();

  static ({String title, String subtitle}) forOperation(
    Operation operation,
    AppLocalizations l10n,
  ) {
    final category = AppCategories.byIdName(operation.categoryId);
    final merchant = operation.note?.trim();

    if (merchant != null && merchant.isNotEmpty) {
      return (
        title: merchant,
        subtitle: category == null ? '' : _categoryPath(category, l10n),
      );
    }

    if (category != null) {
      return (title: category.name(l10n), subtitle: category.groupName(l10n));
    }

    return (title: _fallbackTitle(operation.type, l10n), subtitle: '');
  }

  static String _categoryPath(AppCategory category, AppLocalizations l10n) {
    return '${category.groupName(l10n)} · ${category.name(l10n)}';
  }

  static String _fallbackTitle(OperationType type, AppLocalizations l10n) {
    return switch (type) {
      OperationType.expense => l10n.operationExpense,
      OperationType.income => l10n.operationIncome,
      OperationType.transfer => l10n.operationTransfer,
    };
  }
}
