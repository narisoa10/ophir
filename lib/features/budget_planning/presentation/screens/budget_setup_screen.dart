import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/app_routes.dart';
import '../../../../core/icons/app_icons.dart';
import '../../../../core/localization/generated/app_localizations.dart';
import '../../../../core/theme_v1/app_theme_colors.dart';
import '../../../../core/theme_v1/app_dimensions.dart';
import '../../../../core/theme_v1/app_radius.dart';
import '../../../../core/theme_v1/app_spacing.dart';
import '../../../../core/theme_v1/app_typography.dart';
import '../../controller/budget_setup_controller.dart';
import '../../controller/budget_setup_gate_provider.dart';
import '../../domain/enums/budget_setup_mode.dart';
import '../widgets/budget_household_step.dart';
import '../widgets/budget_income_step.dart';
import '../widgets/budget_mandatory_expenses_step.dart';
import '../widgets/budget_setup_progress.dart';

enum _BudgetSetupStep {
  household,
  income,
  mandatoryExpenses,
  finish;

  static const first = household;
  static const last = finish;

  static int get totalSteps => values.length;

  static _BudgetSetupStep fromIndex(int index) {
    return values[index.clamp(first.index, last.index).toInt()];
  }

  bool get isFirst => this == first;
  bool get isLast => this == last;
}

class BudgetSetupScreen extends ConsumerStatefulWidget {
  const BudgetSetupScreen({required this.mode, super.key});

  final BudgetSetupMode mode;

  @override
  ConsumerState<BudgetSetupScreen> createState() => _BudgetSetupScreenState();
}

class _BudgetSetupScreenState extends ConsumerState<BudgetSetupScreen> {
  final _householdStepKey = GlobalKey<BudgetHouseholdStepState>();
  final _incomeStepKey = GlobalKey<BudgetIncomeStepState>();
  final _mandatoryExpensesStepKey =
      GlobalKey<BudgetMandatoryExpensesStepState>();
  bool _isCompleting = false;
  bool _isCleanedUp = false;
  late ProviderContainer _providerContainer;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _providerContainer = ProviderScope.containerOf(context, listen: false);
  }

  void _cleanupEditDraft() {
    if (widget.mode != BudgetSetupMode.edit) {
      return;
    }
    if (!_isCleanedUp) {
      _isCleanedUp = true;
      final container = _providerContainer;
      final editProvider = budgetSetupControllerProvider(BudgetSetupMode.edit);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        container.refresh(editProvider);
      });
    }
  }

  @override
  void dispose() {
    _cleanupEditDraft();
    super.dispose();
  }

  Future<void> _goBack() async {
    await ref
        .read(budgetSetupControllerProvider(widget.mode).notifier)
        .goToPreviousStep();
  }

  Future<void> _goForward(_BudgetSetupStep currentStep) async {
    final controller = ref.read(
      budgetSetupControllerProvider(widget.mode).notifier,
    );
    final l10n = AppLocalizations.of(context);

    switch (currentStep) {
      case _BudgetSetupStep.household:
        final household = _householdStepKey.currentState
            ?.validateAndCreateHousehold();

        if (household == null) {
          return;
        }

        await controller.saveHouseholdDraftAndGoNext(household);
        break;
      case _BudgetSetupStep.income:
        final incomeSources = _incomeStepKey.currentState
            ?.validateAndCreateIncomeSources();

        if (incomeSources == null) {
          return;
        }

        await controller.saveIncomeSourcesDraftAndGoNext(incomeSources);
        break;
      case _BudgetSetupStep.mandatoryExpenses:
        final obligations = _mandatoryExpensesStepKey.currentState
            ?.validateAndCreateObligations();

        if (obligations == null) {
          return;
        }

        await controller.saveObligationsDraftAndGoNext(obligations);
        break;
      case _BudgetSetupStep.finish:
        if (_isCompleting) {
          return;
        }

        setState(() {
          _isCompleting = true;
        });

        try {
          final isSaved = await controller.completeBudgetSetup();

          if (!mounted) {
            return;
          }

          if (!isSaved) {
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(SnackBar(content: Text(l10n.budgetSetupSaveError)));
            return;
          }

          ref.invalidate(budgetSetupGateProvider);
          await ref.read(budgetSetupGateProvider.future);
          if (mounted) {
            context.go(AppRoutes.dashboard);
          }
        } finally {
          if (mounted) {
            setState(() {
              _isCompleting = false;
            });
          }
        }
    }
  }

  @override
  Widget build(BuildContext context) {
    final setupState = ref.watch(budgetSetupControllerProvider(widget.mode));
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      backgroundColor: context.appThemeColors.background,
      appBar: AppBar(
        backgroundColor: context.appThemeColors.background,
        title: Text(l10n.budgetSetupTitle),
      ),
      bottomNavigationBar: setupState.maybeWhen(
        data: (setup) {
          final currentStep = _BudgetSetupStep.fromIndex(
            setup?.currentStep ?? _BudgetSetupStep.first.index,
          );

          return SafeArea(
            child: Padding(
              padding: AppSpacing.screen,
              child: _BudgetSetupNavigation(
                currentStep: currentStep,
                isCompleting: _isCompleting,
                onBack: _goBack,
                onForward: () => _goForward(currentStep),
              ),
            ),
          );
        },
        orElse: () => null,
      ),
      body: SafeArea(
        child: setupState.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, stackTrace) => _BudgetSetupError(
            message: l10n.budgetSetupDraftLoadError,
            retryLabel: l10n.budgetRetry,
            onRetry: () {
              ref.invalidate(budgetSetupControllerProvider(widget.mode));
            },
          ),
          data: (setup) {
            final currentStep = _BudgetSetupStep.fromIndex(
              setup?.currentStep ?? _BudgetSetupStep.first.index,
            );
            final currencyCode = ref
                .read(budgetSetupControllerProvider(widget.mode).notifier)
                .currencyCode;

            return SingleChildScrollView(
              padding: AppSpacing.screen,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  BudgetSetupProgress(
                    currentStep: currentStep.index,
                    totalSteps: _BudgetSetupStep.totalSteps,
                  ),
                  const SizedBox(height: AppSpacing.screenGap),
                  switch (currentStep) {
                    _BudgetSetupStep.household => BudgetHouseholdStep(
                      key: _householdStepKey,
                      setup: setup,
                    ),
                    _BudgetSetupStep.income
                        when setup != null &&
                            currencyCode != null &&
                            currencyCode.isNotEmpty =>
                      BudgetIncomeStep(
                        key: _incomeStepKey,
                        setup: setup,
                        currencyCode: currencyCode,
                      ),
                    _BudgetSetupStep.income => const Center(
                      child: CircularProgressIndicator(),
                    ),
                    _BudgetSetupStep.mandatoryExpenses
                        when setup != null &&
                            currencyCode != null &&
                            currencyCode.isNotEmpty =>
                      BudgetMandatoryExpensesStep(
                        key: _mandatoryExpensesStepKey,
                        setup: setup,
                        currencyCode: currencyCode,
                      ),
                    _BudgetSetupStep.mandatoryExpenses => const Center(
                      child: CircularProgressIndicator(),
                    ),
                    _BudgetSetupStep.finish => _BudgetSetupPlaceholder(
                      message: l10n.budgetMandatoryExpensesPlaceholder,
                    ),
                  },
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _BudgetSetupNavigation extends StatelessWidget {
  const _BudgetSetupNavigation({
    required this.currentStep,
    required this.isCompleting,
    required this.onBack,
    required this.onForward,
  });

  final _BudgetSetupStep currentStep;
  final bool isCompleting;
  final Future<void> Function() onBack;
  final Future<void> Function() onForward;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = context.appThemeColors;

    return Row(
      mainAxisAlignment: currentStep.isFirst
          ? MainAxisAlignment.end
          : MainAxisAlignment.spaceBetween,
      children: [
        if (!currentStep.isFirst)
          IconButton(
            key: const ValueKey<String>('budget-setup-back-button'),
            tooltip: l10n.budgetBack,
            onPressed: () {
              onBack();
            },
            icon: Transform.flip(
              flipX: true,
              child: Icon(AppIcons.actionForward),
            ),
            color: colors.primary,
            iconSize: AppDimensions.iconMd,
          ),
        if (currentStep.isLast)
          Material(
            color: Colors.transparent,
            child: InkWell(
              key: const ValueKey<String>('budget-setup-finish-button'),
              borderRadius: AppRadius.buttonRadius,
              onTap: isCompleting ? null : onForward,
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  minWidth: AppDimensions.buttonMinWidth,
                  minHeight: AppDimensions.buttonMdHeight,
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (isCompleting)
                        SizedBox.square(
                          dimension: AppDimensions.iconMd,
                          child: CircularProgressIndicator(
                            strokeWidth: AppDimensions.dividerThickness,
                            color: colors.primary,
                          ),
                        )
                      else
                        Icon(
                          AppIcons.actionCheck,
                          color: colors.primary,
                          size: AppDimensions.iconMd,
                        ),
                      const SizedBox(width: AppSpacing.xs),
                      Text(
                        l10n.budgetSetupFinish,
                        style: AppTypography.button.copyWith(
                          color: colors.primary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          )
        else
          IconButton(
            key: const ValueKey<String>('budget-setup-next-button'),
            tooltip: l10n.budgetContinue,
            onPressed: () {
              onForward();
            },
            icon: const Icon(AppIcons.actionForward),
            color: colors.primary,
            iconSize: AppDimensions.iconMd,
          ),
      ],
    );
  }
}

class _BudgetSetupError extends StatelessWidget {
  const _BudgetSetupError({
    required this.message,
    required this.retryLabel,
    required this.onRetry,
  });

  final String message;
  final String retryLabel;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final colors = context.appThemeColors;

    return Center(
      child: Padding(
        padding: AppSpacing.screen,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              message,
              textAlign: TextAlign.center,
              style: AppTypography.body.copyWith(color: colors.textSecondary),
            ),
            const SizedBox(height: AppSpacing.itemGap),
            ElevatedButton(
              onPressed: onRetry,
              style: ElevatedButton.styleFrom(
                backgroundColor: colors.primary,
                foregroundColor: colors.textInverse,
                padding: AppSpacing.buttonInsets,
              ),
              child: Text(retryLabel, style: AppTypography.button),
            ),
          ],
        ),
      ),
    );
  }
}

class _BudgetSetupPlaceholder extends StatelessWidget {
  const _BudgetSetupPlaceholder({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final colors = context.appThemeColors;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: AppRadius.cardRadius,
      ),
      child: Padding(
        padding: AppSpacing.cardInsets,
        child: Text(
          message,
          style: AppTypography.body.copyWith(color: colors.textSecondary),
        ),
      ),
    );
  }
}
