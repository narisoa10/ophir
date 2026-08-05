import 'package:flutter/material.dart';

import '../../../../core/categories/app_categories.dart';
import '../../../../core/localization/generated/app_localizations.dart';

/// Stage 2 — ask whether to remember merchant → category mapping.
Future<RememberCategoryRuleChoice?> showRememberCategoryRuleDialog({
  required BuildContext context,
  required String merchantLabel,
  required AppCategory category,
}) {
  final l10n = AppLocalizations.of(context);

  return showDialog<RememberCategoryRuleChoice>(
    context: context,
    builder: (context) {
      return AlertDialog(
        title: Text(l10n.categoryRuleRememberTitle),
        content: Text('${category.name(l10n)}\n$merchantLabel'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(
              context,
            ).pop(const RememberCategoryRuleChoice(remember: false)),
            child: Text(l10n.categoryRuleRememberOnlyThis),
          ),
          FilledButton(
            onPressed: () => Navigator.of(
              context,
            ).pop(const RememberCategoryRuleChoice(remember: true)),
            child: Text(l10n.categoryRuleRememberConfirm),
          ),
        ],
      );
    },
  );
}

final class RememberCategoryRuleChoice {
  const RememberCategoryRuleChoice({required this.remember});

  final bool remember;
}
