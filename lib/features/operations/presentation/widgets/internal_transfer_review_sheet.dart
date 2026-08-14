import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/errors/app_failure.dart';
import '../../../../core/errors/app_failure_localization.dart';
import '../../../../core/formatters/app_money_formatter.dart';
import '../../../../core/localization/generated/app_localizations.dart';
import '../../../../core/theme_v1/app_radius.dart';
import '../../../../core/theme_v1/app_spacing.dart';
import '../../../../core/theme_v1/app_theme_colors.dart';
import '../../../../core/theme_v1/app_typography.dart';
import '../../controller/internal_transfer_review_providers.dart';
import '../../domain/entities/internal_transfer_review_item.dart';
import '../../domain/internal_transfer_confirm_outcome.dart';

Future<void> showInternalTransferReviewSheet({required BuildContext context}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (sheetContext) {
      return const _InternalTransferReviewSheetBody();
    },
  );
}

class _InternalTransferReviewSheetBody extends ConsumerWidget {
  const _InternalTransferReviewSheetBody();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final state = ref.watch(internalTransferReviewProvider);
    final maxHeight = MediaQuery.sizeOf(context).height * 0.85;

    return SizedBox(
      height: maxHeight,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: AppSpacing.screen,
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    l10n.internalTransferReviewSheetTitle,
                    style: AppTypography.sectionTitle,
                  ),
                ),
                TextButton(
                  onPressed: () => Navigator.of(context).maybePop(),
                  child: Text(l10n.internalTransferReviewClose),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: state.isLoading && state.candidates.isEmpty
                ? const Center(child: CircularProgressIndicator())
                : state.candidates.isEmpty
                ? Center(
                    child: Padding(
                      padding: AppSpacing.screen,
                      child: Text(
                        l10n.internalTransferReviewClose,
                        style: AppTypography.caption,
                      ),
                    ),
                  )
                : ListView.separated(
                    padding: AppSpacing.screen,
                    itemCount: state.candidates.length,
                    separatorBuilder: (_, _) =>
                        const SizedBox(height: AppSpacing.md),
                    itemBuilder: (context, index) {
                      final item = state.candidates[index];
                      return _InternalTransferCandidateCard(
                        item: item,
                        confirming: state.isConfirming(item.reconciliationId),
                        confirmEnabled: !state.hasInFlightConfirm,
                        onConfirm: () => _confirm(context, ref, item),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Future<void> _confirm(
    BuildContext context,
    WidgetRef ref,
    InternalTransferReviewItem item,
  ) async {
    final messenger = ScaffoldMessenger.maybeOf(context);
    final l10n = AppLocalizations.of(context);
    final navigator = Navigator.of(context);

    final outcome = await ref
        .read(internalTransferReviewProvider.notifier)
        .confirm(item.reconciliationId);

    if (!context.mounted) {
      return;
    }

    switch (outcome) {
      case InternalTransferConfirmSucceeded():
        messenger?.showSnackBar(
          SnackBar(content: Text(l10n.internalTransferReviewConfirmed)),
        );
        final remaining = ref.read(internalTransferReviewProvider).candidates;
        if (remaining.isEmpty) {
          navigator.maybePop();
        }
      case InternalTransferConfirmStale():
        messenger?.showSnackBar(
          SnackBar(
            content: Text(l10n.internalTransferReviewSuggestionOutdated),
          ),
        );
      case InternalTransferConfirmUnavailable():
        messenger?.showSnackBar(
          SnackBar(
            content: Text(l10n.internalTransferReviewSuggestionUnavailable),
          ),
        );
        final remaining = ref.read(internalTransferReviewProvider).candidates;
        if (remaining.isEmpty) {
          navigator.maybePop();
        }
      case InternalTransferConfirmUnauthorized():
        messenger?.showSnackBar(
          SnackBar(content: Text(const UnauthorizedFailure().localized(l10n))),
        );
      case InternalTransferConfirmInvalidRequest():
        messenger?.showSnackBar(
          SnackBar(content: Text(l10n.failureValidation)),
        );
      case InternalTransferConfirmRetryableFailure(:final failure):
        messenger?.showSnackBar(
          SnackBar(
            content: Text(
              failure is NetworkFailure
                  ? l10n.failureNetwork
                  : l10n.internalTransferReviewRetry,
            ),
          ),
        );
    }
  }
}

class _InternalTransferCandidateCard extends StatelessWidget {
  const _InternalTransferCandidateCard({
    required this.item,
    required this.confirming,
    required this.confirmEnabled,
    required this.onConfirm,
  });

  final InternalTransferReviewItem item;
  final bool confirming;
  final bool confirmEnabled;
  final VoidCallback onConfirm;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = context.appThemeColors;

    return Material(
      color: colors.surface,
      borderRadius: AppRadius.cardRadius,
      child: Padding(
        padding: AppSpacing.cardInsets,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              formatMoney(
                item.amount,
                item.currencyCode,
                showPositiveSign: false,
              ),
              style: AppTypography.sectionTitle,
            ),
            const SizedBox(height: AppSpacing.sm),
            _LabeledValue(
              label: l10n.internalTransferReviewFrom,
              value: _accountLabel(item.outgoingAccount, l10n),
            ),
            const SizedBox(height: AppSpacing.xs),
            _LabeledValue(
              label: l10n.internalTransferReviewTo,
              value: _accountLabel(item.incomingAccount, l10n),
            ),
            const SizedBox(height: AppSpacing.sm),
            _LabeledValue(
              label: l10n.internalTransferReviewOutgoingDate,
              value: _formatDate(item.outgoingDate),
            ),
            const SizedBox(height: AppSpacing.xs),
            _LabeledValue(
              label: l10n.internalTransferReviewIncomingDate,
              value: _formatDate(item.incomingDate),
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              l10n.internalTransferReviewSourceOperations,
              style: AppTypography.caption.copyWith(
                color: colors.textSecondary,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            if (item.outgoingOperation != null)
              _OperationSummaryRow(
                operation: item.outgoingOperation!,
                currencyCode: item.currencyCode,
              ),
            if (item.incomingOperation != null) ...[
              const SizedBox(height: AppSpacing.xs),
              _OperationSummaryRow(
                operation: item.incomingOperation!,
                currencyCode: item.currencyCode,
              ),
            ],
            const SizedBox(height: AppSpacing.md),
            Text(
              l10n.internalTransferReviewExplanation,
              style: AppTypography.caption.copyWith(
                color: colors.textSecondary,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            FilledButton(
              onPressed: confirming || !confirmEnabled ? null : onConfirm,
              child: confirming
                  ? const SizedBox(
                      height: 18,
                      width: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(l10n.internalTransferReviewConfirm),
            ),
          ],
        ),
      ),
    );
  }

  String _accountLabel(
    InternalTransferReviewAccount account,
    AppLocalizations l10n,
  ) {
    if (!account.available ||
        account.displayName == null ||
        account.displayName!.trim().isEmpty) {
      return l10n.internalTransferReviewUnavailableAccount;
    }

    final name = account.displayName!.trim();
    final mask = account.mask?.trim();
    if (mask == null || mask.isEmpty) {
      return name;
    }
    return '$name ···$mask';
  }

  String _formatDate(DateTime date) {
    final year = date.year.toString().padLeft(4, '0');
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '$year-$month-$day';
  }
}

class _LabeledValue extends StatelessWidget {
  const _LabeledValue({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 120,
          child: Text(
            label,
            style: AppTypography.caption.copyWith(
              color: context.appThemeColors.textSecondary,
            ),
          ),
        ),
        Expanded(child: Text(value, style: AppTypography.body)),
      ],
    );
  }
}

class _OperationSummaryRow extends StatelessWidget {
  const _OperationSummaryRow({
    required this.operation,
    required this.currencyCode,
  });

  final InternalTransferReviewOperation operation;
  final String currencyCode;

  @override
  Widget build(BuildContext context) {
    final note = operation.note?.trim();
    final title = (note != null && note.isNotEmpty) ? note : operation.type;
    final amount = formatMoney(
      operation.amount,
      currencyCode,
      showPositiveSign: false,
    );

    return Text(
      '$title · ${_formatDate(operation.occurredAt)} · $amount',
      style: AppTypography.body,
    );
  }

  String _formatDate(DateTime date) {
    final year = date.year.toString().padLeft(4, '0');
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '$year-$month-$day';
  }
}
