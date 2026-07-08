import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/errors/result.dart';
import '../../../../core/localization/generated/app_localizations.dart';
import '../../../../core/theme_v1/app_colors.dart';
import '../../../../core/theme_v1/app_typography.dart';
import '../../../categories/controller/category_picker_taxonomy_providers.dart';
import '../../../categories/domain/enums/category_type.dart';
import '../../../categories/presentation/models/category_picker_taxonomy_section.dart';
import '../widgets/operation_app_bar.dart';
import '../widgets/operation_taxonomy_category_section_list.dart';

class OperationCategoryPickerScreen extends ConsumerWidget {
  const OperationCategoryPickerScreen({required this.type, super.key});

  final CategoryType type;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final sectionsState = type == CategoryType.expense
        ? ref.watch(expenseCategoryPickerTaxonomySectionsProvider(l10n))
        : ref.watch(incomeCategoryPickerTaxonomySectionsProvider(l10n));

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: OperationAppBar(title: l10n.operationChooseCategory),
      body: SafeArea(
        child: sectionsState.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, stackTrace) => Center(
            child: Text(l10n.failureUnknown, style: AppTypography.caption),
          ),
          data: (result) {
            return switch (result) {
              Success<List<CategoryPickerTaxonomySection>>(:final value) =>
                value.isEmpty
                    ? Center(
                        child: Text(
                          l10n.operationCategoryPickerEmpty,
                          style: AppTypography.caption,
                        ),
                      )
                    : OperationTaxonomyCategorySectionList(
                        sections: value,
                        onCategorySelected: context.pop,
                      ),
              Failure<List<CategoryPickerTaxonomySection>>() => Center(
                child: Text(l10n.failureUnknown, style: AppTypography.caption),
              ),
            };
          },
        ),
      ),
    );
  }
}
