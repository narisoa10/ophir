import 'package:flutter/material.dart';

abstract final class AppAccountIcons {
  AppAccountIcons._();

  static const String cash = 'cash';
  static const String bank = 'bank';
  static const String card = 'card';
  static const String creditCard = 'credit_card';
  static const String savings = 'savings';
  static const String investment = 'investment';
  static const String loan = 'loan';
  static const String wallet = 'wallet';
  static const String other = 'other';

  static IconData fromKey(String key) {
    return switch (key) {
      cash => Icons.payments_outlined,
      bank => Icons.account_balance_outlined,
      card => Icons.credit_card_outlined,
      creditCard => Icons.credit_score_outlined,
      savings => Icons.savings_outlined,
      investment => Icons.trending_up_rounded,
      loan => Icons.request_quote_outlined,
      wallet => Icons.account_balance_wallet_outlined,
      other => Icons.account_balance_wallet_outlined,
      _ => Icons.account_balance_wallet_outlined,
    };
  }
}