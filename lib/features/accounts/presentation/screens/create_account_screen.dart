import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/errors/result.dart';
import '../../../../core/localization/generated/app_localizations.dart';
import '../../../../core/theme_v1/app_theme_colors.dart';
import '../../../../core/theme_v1/app_radius.dart';
import '../../../../core/theme_v1/app_spacing.dart';
import '../../../../core/theme_v1/app_typography.dart';
import '../../controller/account_controller.dart';
import '../../controller/create_manual_account_command.dart';
import '../../domain/enums/account_type.dart';

class CreateAccountScreen extends ConsumerStatefulWidget {
  const CreateAccountScreen({super.key});

  @override
  ConsumerState<CreateAccountScreen> createState() =>
      _CreateAccountScreenState();
}

class _CreateAccountScreenState extends ConsumerState<CreateAccountScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _balanceController = TextEditingController();

  AccountType _type = AccountType.bank;
  String _currencyCode = 'CAD';
  bool _isSaving = false;

  @override
  void dispose() {
    _nameController.dispose();
    _balanceController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate() || _isSaving) {
      return;
    }

    setState(() {
      _isSaving = true;
    });

    final result = await ref
        .read(accountControllerProvider.notifier)
        .createManualAccount(
          CreateManualAccountCommand(
            name: _nameController.text.trim(),
            type: _type,
            currencyCode: _currencyCode,
            initialBalance: double.parse(_balanceController.text.trim()),
          ),
        );

    if (!mounted) {
      return;
    }

    setState(() {
      _isSaving = false;
    });

    switch (result) {
      case Success():
        context.pop();
      case Failure():
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context).failureUnknown)),
        );
    }
  }

  String _typeLabel(AccountType type, AppLocalizations l10n) {
    return switch (type) {
      AccountType.cash => l10n.accountTypeCash,
      AccountType.bank => l10n.accountTypeBank,
      AccountType.card => l10n.accountTypeCard,
      AccountType.creditCard => l10n.accountTypeCreditCard,
      AccountType.savings => l10n.accountTypeSavings,
      AccountType.investment => l10n.accountTypeInvestment,
      AccountType.loan => l10n.accountTypeLoan,
      AccountType.wallet => l10n.accountTypeWallet,
      AccountType.other => l10n.accountTypeOther,
    };
  }

  InputDecoration _inputDecoration(String hintText) {
    final colors = context.appThemeColors;

    return InputDecoration(
      hintText: hintText,
      filled: true,
      fillColor: colors.surface,
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
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      backgroundColor: context.appThemeColors.background,
      appBar: AppBar(
        backgroundColor: context.appThemeColors.background,
        title: Text(l10n.accountCreateTitle),
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: AppSpacing.screen,
            children: [
              TextFormField(
                controller: _nameController,
                decoration: _inputDecoration(l10n.accountNameHint),
                textInputAction: TextInputAction.next,
                validator: (value) {
                  final text = value?.trim() ?? '';

                  if (text.isEmpty) {
                    return l10n.accountNameRequired;
                  }

                  return null;
                },
              ),
              const SizedBox(height: AppSpacing.lg),
              DropdownButtonFormField<AccountType>(
                initialValue: _type,
                decoration: _inputDecoration(l10n.accountTypeHint),
                items: [
                  for (final type in AccountType.values)
                    DropdownMenuItem(
                      value: type,
                      child: Text(_typeLabel(type, l10n)),
                    ),
                ],
                onChanged: (value) {
                  if (value == null) {
                    return;
                  }

                  setState(() {
                    _type = value;
                  });
                },
              ),
              const SizedBox(height: AppSpacing.lg),
              DropdownButtonFormField<String>(
                initialValue: _currencyCode,
                decoration: _inputDecoration(l10n.accountCurrencyHint),
                items: const [
                  DropdownMenuItem(value: 'CAD', child: Text('CAD')),
                  DropdownMenuItem(value: 'USD', child: Text('USD')),
                  DropdownMenuItem(value: 'EUR', child: Text('EUR')),
                ],
                onChanged: (value) {
                  if (value == null) {
                    return;
                  }

                  setState(() {
                    _currencyCode = value;
                  });
                },
              ),
              const SizedBox(height: AppSpacing.lg),
              TextFormField(
                controller: _balanceController,
                decoration: _inputDecoration(l10n.accountInitialBalanceHint),
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
                ],
                validator: (value) {
                  final text = value?.trim() ?? '';

                  if (text.isEmpty) {
                    return l10n.accountInitialBalanceRequired;
                  }

                  if (double.tryParse(text) == null) {
                    return l10n.accountInitialBalanceInvalid;
                  }

                  return null;
                },
              ),
              const SizedBox(height: AppSpacing.xxxl),
              ElevatedButton(
                onPressed: _isSaving ? null : _save,
                style: ElevatedButton.styleFrom(
                  backgroundColor: context.appThemeColors.primary,
                  foregroundColor: context.appThemeColors.textInverse,
                  padding: AppSpacing.buttonInsets,
                  shape: AppRadius.buttonShape,
                ),
                child: _isSaving
                    ? const CircularProgressIndicator()
                    : Text(l10n.commonApply, style: AppTypography.titleMd),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
