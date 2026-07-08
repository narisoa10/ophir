import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/errors/result.dart';
import '../../../../core/icons/app_account_icons.dart';
import '../../../../core/localization/generated/app_localizations.dart';
import '../../../../core/theme/app_category_colors.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../controller/account_controller.dart';
import '../../domain/entities/account.dart';
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

    final now = DateTime.now();
    final account = Account(
      id: '',
      userId: '',
      name: _nameController.text.trim(),
      type: _type,
      currencyCode: _currencyCode,
      initialBalance: double.parse(_balanceController.text.trim()),
      iconKey: _iconKey(_type),
      colorKey: _colorKey(_type),
      sortOrder: 0,
      isArchived: false,
      createdAt: now,
      updatedAt: now,
    );

    final result = await ref
        .read(accountControllerProvider.notifier)
        .createAccount(account);

    if (!mounted) {
      return;
    }

    setState(() {
      _isSaving = false;
    });

    switch (result) {
      case Success<Account>():
        context.pop();
      case Failure<Account>():
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context).failureUnknown),
          ),
        );
    }
  }

  String _iconKey(AccountType type) {
    return switch (type) {
      AccountType.cash => AppAccountIcons.cash,
      AccountType.bank => AppAccountIcons.bank,
      AccountType.card => AppAccountIcons.card,
      AccountType.creditCard => AppAccountIcons.creditCard,
      AccountType.savings => AppAccountIcons.savings,
      AccountType.investment => AppAccountIcons.investment,
      AccountType.loan => AppAccountIcons.loan,
      AccountType.wallet => AppAccountIcons.wallet,
      AccountType.other => AppAccountIcons.other,
    };
  }

  String _colorKey(AccountType type) {
    return switch (type) {
      AccountType.cash => AppCategoryColors.green,
      AccountType.bank => AppCategoryColors.blue,
      AccountType.card => AppCategoryColors.purple,
      AccountType.creditCard => AppCategoryColors.red,
      AccountType.savings => AppCategoryColors.green,
      AccountType.investment => AppCategoryColors.orange,
      AccountType.loan => AppCategoryColors.red,
      AccountType.wallet => AppCategoryColors.cyan,
      AccountType.other => AppCategoryColors.gray,
    };
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
    return InputDecoration(
      hintText: hintText,
      filled: true,
      fillColor: AppColors.surface,
      border: const OutlineInputBorder(
        borderRadius: AppRadius.inputRadius,
        borderSide: BorderSide(color: AppColors.border),
      ),
      enabledBorder: const OutlineInputBorder(
        borderRadius: AppRadius.inputRadius,
        borderSide: BorderSide(color: AppColors.border),
      ),
      focusedBorder: const OutlineInputBorder(
        borderRadius: AppRadius.inputRadius,
        borderSide: BorderSide(color: AppColors.primary),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
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
                  FilteringTextInputFormatter.allow(
                    RegExp(r'^\d*\.?\d{0,2}'),
                  ),
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
                  backgroundColor: AppColors.primary,
                  foregroundColor: AppColors.textInverse,
                  padding: AppSpacing.buttonInsets,
                  shape: AppRadius.buttonShape,
                ),
                child: _isSaving
                    ? const CircularProgressIndicator()
                    : Text(
                  l10n.commonApply,
                  style: AppTypography.titleMd,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}