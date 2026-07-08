import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/app_routes.dart';
import '../../../../core/errors/result.dart';
import '../../../../core/icons/app_icons.dart';
import '../../../../core/localization/generated/app_localizations.dart';
import '../../../../core/theme_v1/app_colors.dart';
import '../../../../core/theme_v1/app_spacing.dart';
import '../../../../core/theme_v1/app_typography.dart';
import '../../../categories/domain/entities/category.dart';
import '../../controller/operation_controller.dart';
import '../../controller/operation_display_categories_provider.dart';
import '../../domain/entities/operation.dart';
import '../adapters/operation_adapter.dart';
import '../widgets/operation_date_section_list.dart';
import '../widgets/operations_empty_state.dart';

class OperationsScreen extends ConsumerWidget {
  const OperationsScreen({super.key});

  void _openOperationEditor(BuildContext context, Operation operation) {
    context.push(AppRoutes.createOperation, extra: operation);
  }

  Future<bool> _confirmArchiveOperation(
    BuildContext context,
    WidgetRef ref,
    Operation operation,
  ) async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(l10n.operationArchiveTitle),
          content: Text(l10n.operationArchiveMessage),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(l10n.commonCancel),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: Text(l10n.operationArchiveConfirm),
            ),
          ],
        );
      },
    );

    if (confirmed != true) {
      return false;
    }

    final result = await ref
        .read(operationControllerProvider.notifier)
        .archiveOperation(operation.id);

    if (!context.mounted) {
      return result is Success<void>;
    }

    return switch (result) {
      Success<void>() => true,
      Failure<void>() => () {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(l10n.failureUnknown)));
        return false;
      }(),
    };
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final operationsState = ref.watch(operationControllerProvider);
    final categoriesState = ref.watch(operationDisplayCategoriesProvider);
    final l10n = AppLocalizations.of(context);
    const adapter = OperationAdapter();

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Padding(
          padding: AppSpacing.screen,
          child: operationsState.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, stackTrace) => Center(
              child: Text(l10n.failureUnknown, style: AppTypography.caption),
            ),
            data: (result) {
              return switch (result) {
                Success<List<Operation>>(:final value) =>
                  value.isEmpty
                      ? const OperationsEmptyState()
                      : categoriesState.when(
                          loading: () =>
                              const Center(child: CircularProgressIndicator()),
                          error: (error, stackTrace) => Center(
                            child: Text(
                              l10n.failureUnknown,
                              style: AppTypography.caption,
                            ),
                          ),
                          data: (categoriesResult) {
                            return switch (categoriesResult) {
                              Success<List<Category>>(
                                value: final categories,
                              ) =>
                                OperationDateSectionList(
                                  title: l10n.operationsTitle,
                                  hint: l10n.operationsInteractionHint,
                                  presentation: adapter.toListPresentation(
                                    value,
                                    categories,
                                    l10n,
                                    MaterialLocalizations.of(
                                      context,
                                    ).formatMediumDate,
                                  ),
                                  onOperationTap: (operation) {
                                    _openOperationEditor(
                                      context,
                                      operation.operation,
                                    );
                                  },
                                  onOperationArchive: (operation) {
                                    return _confirmArchiveOperation(
                                      context,
                                      ref,
                                      operation.operation,
                                    );
                                  },
                                ),
                              Failure<List<Category>>() =>
                                const OperationsEmptyState(),
                            };
                          },
                        ),
                Failure<List<Operation>>() => const OperationsEmptyState(),
              };
            },
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.textInverse,
        onPressed: () => context.push(AppRoutes.createOperation),
        child: const Icon(AppIcons.actionAdd),
      ),
    );
  }
}
