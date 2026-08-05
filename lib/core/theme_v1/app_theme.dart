import 'package:flutter/material.dart';

import 'app_dimensions.dart';
import 'app_radius.dart';
import 'app_spacing.dart';
import 'app_theme_colors.dart';
import 'app_typography.dart';

abstract final class AppTheme {
  AppTheme._();

  static ThemeData get light {
    return _buildTheme(
      brightness: Brightness.light,
      colors: AppThemeColors.light,
    );
  }

  static ThemeData get dark {
    return _buildTheme(
      brightness: Brightness.dark,
      colors: AppThemeColors.dark,
    );
  }

  static ThemeData _buildTheme({
    required Brightness brightness,
    required AppThemeColors colors,
  }) {
    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      fontFamily: AppTypography.fontFamily,
      scaffoldBackgroundColor: colors.background,
      colorScheme: _colorScheme(brightness: brightness, colors: colors),
      textTheme: AppTypography.textTheme.apply(
        bodyColor: colors.textPrimary,
        displayColor: colors.textPrimary,
      ),
      appBarTheme: _appBarTheme(colors),
      elevatedButtonTheme: _elevatedButtonTheme(colors),
      textButtonTheme: _textButtonTheme(colors),
      inputDecorationTheme: _inputDecorationTheme(colors),
      navigationBarTheme: _navigationBarTheme(colors),
      extensions: <ThemeExtension<dynamic>>[colors],
    );
  }

  static ColorScheme _colorScheme({
    required Brightness brightness,
    required AppThemeColors colors,
  }) {
    return ColorScheme(
      brightness: brightness,
      primary: colors.primary,
      onPrimary: colors.textInverse,
      secondary: colors.success,
      onSecondary: colors.textInverse,
      error: colors.error,
      onError: colors.textInverse,
      surface: colors.surface,
      onSurface: colors.textPrimary,
    );
  }

  static AppBarTheme _appBarTheme(AppThemeColors colors) {
    return AppBarTheme(
      elevation: AppSpacing.none,
      scrolledUnderElevation: AppSpacing.none,
      centerTitle: true,
      toolbarHeight: AppDimensions.appBarHeight,
      backgroundColor: colors.background,
      foregroundColor: colors.textPrimary,
      iconTheme: IconThemeData(
        color: colors.iconPrimary,
        size: AppDimensions.iconLg,
      ),
      titleTextStyle: AppTypography.titleLg.copyWith(color: colors.textPrimary),
    );
  }

  static ElevatedButtonThemeData _elevatedButtonTheme(AppThemeColors colors) {
    return ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        elevation: AppSpacing.none,
        minimumSize: const Size(
          AppDimensions.buttonMinWidth,
          AppDimensions.buttonMdHeight,
        ),
        backgroundColor: colors.primary,
        foregroundColor: colors.textInverse,
        disabledBackgroundColor: colors.primaryLight,
        disabledForegroundColor: colors.textDisabled,
        textStyle: AppTypography.buttonMd,
        padding: AppSpacing.buttonInsets,
        shape: AppRadius.buttonShape,
      ),
    );
  }

  static TextButtonThemeData _textButtonTheme(AppThemeColors colors) {
    return TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: colors.primary,
        disabledForegroundColor: colors.textDisabled,
        textStyle: AppTypography.buttonMd,
        padding: AppSpacing.buttonInsets,
        shape: AppRadius.buttonShape,
      ),
    );
  }

  static InputDecorationTheme _inputDecorationTheme(AppThemeColors colors) {
    return InputDecorationTheme(
      filled: true,
      fillColor: colors.surface,
      hintStyle: AppTypography.bodyMd.copyWith(color: colors.textTertiary),
      labelStyle: AppTypography.bodyMd.copyWith(color: colors.textSecondary),
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

  static NavigationBarThemeData _navigationBarTheme(AppThemeColors colors) {
    return NavigationBarThemeData(
      height: AppDimensions.bottomNavHeight,
      elevation: AppSpacing.none,
      backgroundColor: colors.surface,
      indicatorColor: colors.primaryLight,
      labelTextStyle: WidgetStateProperty.resolveWith((states) {
        final isSelected = states.contains(WidgetState.selected);

        return AppTypography.labelSm.copyWith(
          color: isSelected ? colors.primary : colors.textSecondary,
        );
      }),
      iconTheme: WidgetStateProperty.resolveWith((states) {
        final isSelected = states.contains(WidgetState.selected);

        return IconThemeData(
          color: isSelected ? colors.primary : colors.iconSecondary,
          size: AppDimensions.bottomNavIconSize,
        );
      }),
    );
  }
}
