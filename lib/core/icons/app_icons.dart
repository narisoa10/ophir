import 'package:flutter/material.dart';

abstract final class AppIcons {
  AppIcons._();

  // Auth assets
  static const String google = 'assets/icons/auth/google.png';
  static const String apple = 'assets/icons/auth/apple.png';
  static const String eye = 'assets/icons/auth/eye.png';
  static const String eyeOff = 'assets/icons/auth/eye_off.png';
  static const String logo = 'assets/icons/auth/logo.svg';

  // Navigation
  static const IconData navigationHome = Icons.home_outlined;
  static const IconData navigationAccounts =
      Icons.account_balance_wallet_outlined;
  static const IconData navigationOperations = Icons.sync_alt_rounded;
  static const IconData navigationStatistics = Icons.bar_chart_rounded;
  static const IconData navigationProfile = Icons.person_outline;

  // Actions
  static const IconData actionNotifications = Icons.notifications_none_rounded;
  static const IconData actionSearch = Icons.search_rounded;
  static const IconData actionAdd = Icons.add_rounded;
  static const IconData actionBack = Icons.arrow_back_ios_new_rounded;
  static const IconData actionChevronRight = Icons.chevron_right_rounded;
  static const IconData actionChevronDown = Icons.keyboard_arrow_down_rounded;
  static const IconData actionCamera = Icons.photo_camera_outlined;

  // Profile
  static const IconData profileEdit = Icons.person_outline;
  static const IconData profileSecurity = Icons.security_outlined;
  static const IconData profileNotifications = Icons.notifications_none_rounded;
  static const IconData profileAppearance = Icons.palette_outlined;
  static const IconData profileLogout = Icons.logout_rounded;

  // Categories / Operations
  static const IconData categoryHousing = Icons.home_work_outlined;
  static const IconData categoryGroceries = Icons.shopping_basket_outlined;
  static const IconData categoryTransport = Icons.directions_bus_outlined;
  static const IconData categoryHealth = Icons.favorite_border_rounded;
  static const IconData categoryRestaurant = Icons.restaurant_outlined;
  static const IconData categoryEducation = Icons.school_outlined;
  static const IconData categoryIncome = Icons.payments_outlined;

  static const IconData operationExpense = Icons.north_east_rounded;
  static const IconData operationIncome = Icons.south_west_rounded;
  static const IconData operationRepeat = Icons.repeat_rounded;

  static const IconData actionCalendar = Icons.calendar_today_outlined;
  static const IconData operationCategory = Icons.category_outlined;
}
