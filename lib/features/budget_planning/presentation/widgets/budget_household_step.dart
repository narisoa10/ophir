import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/localization/generated/app_localizations.dart';
import '../../../../core/theme_v1/app_theme_colors.dart';
import '../../../../core/theme_v1/app_dimensions.dart';
import '../../../../core/theme_v1/app_radius.dart';
import '../../../../core/theme_v1/app_spacing.dart';
import '../../../../core/theme_v1/app_typography.dart';
import '../../domain/entities/budget_household.dart';
import '../../domain/entities/budget_setup.dart';

class BudgetHouseholdStep extends ConsumerStatefulWidget {
  const BudgetHouseholdStep({required this.setup, super.key});

  final BudgetSetup? setup;

  @override
  BudgetHouseholdStepState createState() => BudgetHouseholdStepState();
}

class BudgetHouseholdStepState extends ConsumerState<BudgetHouseholdStep> {
  final _formKey = GlobalKey<FormState>();
  final _adultsController = TextEditingController();
  final _childrenController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _applySetup(widget.setup);
  }

  @override
  void didUpdateWidget(BudgetHouseholdStep oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.setup != widget.setup) {
      _applySetup(widget.setup);
    }
  }

  @override
  void dispose() {
    _adultsController.dispose();
    _childrenController.dispose();
    super.dispose();
  }

  void _applySetup(BudgetSetup? setup) {
    final household = setup?.household;

    _adultsController.text = (household?.adultsCount ?? 1).toString();
    _childrenController.text = (household?.childrenCount ?? 0).toString();
  }

  BudgetHousehold? validateAndCreateHousehold() {
    if (!_formKey.currentState!.validate()) {
      return null;
    }

    return BudgetHousehold(
      adultsCount: int.parse(_adultsController.text.trim()),
      childrenCount: int.parse(_childrenController.text.trim()),
    );
  }

  int? _parseInt(String? value) {
    final text = value?.trim() ?? '';

    if (text.isEmpty) {
      return null;
    }

    return int.tryParse(text);
  }

  String? _requiredIntegerValidator(String? value, int minimumValue) {
    final parsedValue = _parseInt(value);

    if (parsedValue == null || parsedValue < minimumValue) {
      return AppLocalizations.of(context).budgetRequiredField;
    }

    return null;
  }

  InputDecoration _inputDecoration(String labelText) {
    final colors = context.appThemeColors;

    return InputDecoration(
      labelText: labelText,
      isDense: true,
      filled: true,
      fillColor: colors.surface,
      constraints: const BoxConstraints(minHeight: AppDimensions.inputMdHeight),
      contentPadding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      border: OutlineInputBorder(
        borderRadius: AppRadius.inputRadius,
        borderSide: BorderSide(color: colors.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: AppRadius.inputRadius,
        borderSide: BorderSide(color: colors.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: AppRadius.inputRadius,
        borderSide: BorderSide(color: colors.primary),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: AppRadius.inputRadius,
        borderSide: BorderSide(color: colors.error),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: AppRadius.inputRadius,
        borderSide: BorderSide(color: colors.error),
      ),
    );
  }

  Widget _buildHouseholdFields(AppLocalizations l10n) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final useTwoColumns =
            constraints.maxWidth >= AppDimensions.formTwoColumnBreakpoint;

        final adultsField = TextFormField(
          controller: _adultsController,
          decoration: _inputDecoration(l10n.budgetAdultsCount),
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          textInputAction: TextInputAction.next,
          validator: (value) => _requiredIntegerValidator(value, 1),
        );

        final childrenField = TextFormField(
          controller: _childrenController,
          decoration: _inputDecoration(l10n.budgetChildrenCount),
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          textInputAction: TextInputAction.done,
          validator: (value) => _requiredIntegerValidator(value, 0),
        );

        if (!useTwoColumns) {
          return Column(
            children: [
              adultsField,
              const SizedBox(height: AppSpacing.itemGap),
              childrenField,
            ],
          );
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: adultsField),
            const SizedBox(width: AppSpacing.inlineGap),
            Expanded(child: childrenField),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l10n.budgetHouseholdTitle, style: AppTypography.headingMd),
          const SizedBox(height: AppSpacing.sectionGap),
          _buildHouseholdFields(l10n),
        ],
      ),
    );
  }
}
