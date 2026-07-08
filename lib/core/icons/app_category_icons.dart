import 'package:flutter/material.dart';

abstract final class AppCategoryIcons {
  AppCategoryIcons._();

  static const String housing = 'housing';
  static const String groceries = 'groceries';
  static const String transport = 'transport';
  static const String restaurant = 'restaurant';
  static const String health = 'health';
  static const String shopping = 'shopping';
  static const String entertainment = 'entertainment';
  static const String education = 'education';
  static const String savings = 'savings';
  static const String investment = 'investment';
  static const String salary = 'salary';
  static const String freelance = 'freelance';
  static const String transfer = 'transfer';
  static const String other = 'other';

  static IconData fromKey(String key) {
    return switch (key) {
      housing => Icons.home_work_outlined,
      groceries => Icons.shopping_basket_outlined,
      transport => Icons.directions_bus_outlined,
      restaurant => Icons.restaurant_outlined,
      health => Icons.favorite_border_rounded,
      shopping => Icons.shopping_bag_outlined,
      entertainment => Icons.movie_outlined,
      education => Icons.school_outlined,
      savings => Icons.savings_outlined,
      investment => Icons.trending_up_rounded,
      salary => Icons.payments_outlined,
      freelance => Icons.work_outline_rounded,
      transfer => Icons.sync_alt_rounded,
      other => Icons.category_outlined,
      _ => Icons.category_outlined,
    };
  }
}