import 'package:flutter/material.dart';

import 'app_borders.dart';
import 'app_colors.dart';
import 'app_curves.dart';
import 'app_dimensions.dart';
import 'app_durations.dart';
import 'app_radius.dart';
import 'app_spacing.dart';
import 'app_typography.dart';
import 'theme_extensions.dart';

abstract final class AppTheme {
  AppTheme._();

  //────────────────────────────────────────────────────────
  // LIGHT THEME
  //────────────────────────────────────────────────────────

  static ThemeData get light {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      fontFamily: AppTypography.fontFamily,
      scaffoldBackgroundColor: AppColors.background,
      colorScheme: _lightColorScheme,
      textTheme: AppTypography.textTheme,
      appBarTheme: _appBarTheme,
      cardTheme: _cardTheme,
      inputDecorationTheme: _inputDecorationTheme,
      elevatedButtonTheme: _elevatedButtonTheme,
      filledButtonTheme: _filledButtonTheme,
      outlinedButtonTheme: _outlinedButtonTheme,
      textButtonTheme: _textButtonTheme,
      iconTheme: _iconTheme,
      dividerTheme: _dividerTheme,
      bottomNavigationBarTheme: _bottomNavigationBarTheme,
      navigationBarTheme: _navigationBarTheme,
      dialogTheme: _dialogTheme,
      bottomSheetTheme: _bottomSheetTheme,
      snackBarTheme: _snackBarTheme,
      pageTransitionsTheme: _pageTransitionsTheme,
      extensions: const <ThemeExtension<dynamic>>[
        AppThemeExtension.light,
      ],
    );
  }

  //────────────────────────────────────────────────────────
  // COLOR SCHEME
  //────────────────────────────────────────────────────────

  static const ColorScheme _lightColorScheme = ColorScheme(
    brightness: Brightness.light,
    primary: AppColors.primary,
    onPrimary: AppColors.textInverse,
    secondary: AppColors.success,
    onSecondary: AppColors.textInverse,
    error: AppColors.error,
    onError: AppColors.textInverse,
    surface: AppColors.surface,
    onSurface: AppColors.textPrimary,
  );

  //────────────────────────────────────────────────────────
  // APP BAR
  //────────────────────────────────────────────────────────

  static final AppBarTheme _appBarTheme = AppBarTheme(
    elevation: 0,
    scrolledUnderElevation: 0,
    centerTitle: true,
    toolbarHeight: AppDimensions.appBarHeight,
    backgroundColor: AppColors.background,
    foregroundColor: AppColors.textPrimary,
    iconTheme: const IconThemeData(
      color: AppColors.iconPrimary,
      size: AppDimensions.appBarIconSize,
    ),
    titleTextStyle: AppTypography.titleLg,
  );

  //────────────────────────────────────────────────────────
  // CARDS
  //────────────────────────────────────────────────────────

  static const CardThemeData _cardTheme = CardThemeData(
    elevation: 0,
    color: AppColors.surface,
    surfaceTintColor: AppColors.transparent,
    margin: EdgeInsets.zero,
    shape: AppRadius.cardShape,
  );

  //────────────────────────────────────────────────────────
  // INPUTS
  //────────────────────────────────────────────────────────

  static final InputDecorationTheme _inputDecorationTheme =
  InputDecorationTheme(
    filled: true,
    fillColor: AppColors.surfaceSoft,
    hintStyle: AppTypography.bodyMd.copyWith(
      color: AppColors.textTertiary,
    ),
    labelStyle: AppTypography.bodyMd.copyWith(
      color: AppColors.textSecondary,
    ),
    errorStyle: AppTypography.captionLg.copyWith(
      color: AppColors.error,
    ),
    contentPadding: AppSpacing.inputInsets,
    border: AppBorders.input,
    enabledBorder: AppBorders.input,
    focusedBorder: AppBorders.inputFocused,
    errorBorder: AppBorders.inputError,
    focusedErrorBorder: AppBorders.inputError,
    disabledBorder: AppBorders.inputDisabled,
  );

  //────────────────────────────────────────────────────────
  // ELEVATED BUTTONS
  //────────────────────────────────────────────────────────

  static final ElevatedButtonThemeData _elevatedButtonTheme =
  ElevatedButtonThemeData(
    style: ElevatedButton.styleFrom(
      elevation: 0,
      minimumSize: const Size(
        AppDimensions.buttonMinWidth,
        AppDimensions.buttonMdHeight,
      ),
      backgroundColor: AppColors.primary,
      foregroundColor: AppColors.textInverse,
      disabledBackgroundColor: AppColors.primaryLight,
      disabledForegroundColor: AppColors.textDisabled,
      textStyle: AppTypography.buttonMd,
      padding: AppSpacing.buttonInsets,
      shape: AppRadius.buttonShape,
      animationDuration: AppDurations.button,
    ),
  );

  //────────────────────────────────────────────────────────
  // FILLED BUTTONS
  //────────────────────────────────────────────────────────

  static final FilledButtonThemeData _filledButtonTheme =
  FilledButtonThemeData(
    style: FilledButton.styleFrom(
      minimumSize: const Size(
        AppDimensions.buttonMinWidth,
        AppDimensions.buttonMdHeight,
      ),
      backgroundColor: AppColors.primary,
      foregroundColor: AppColors.textInverse,
      disabledBackgroundColor: AppColors.primaryLight,
      disabledForegroundColor: AppColors.textDisabled,
      textStyle: AppTypography.buttonMd,
      padding: AppSpacing.buttonInsets,
      shape: AppRadius.buttonShape,
      animationDuration: AppDurations.button,
    ),
  );

  //────────────────────────────────────────────────────────
  // OUTLINED BUTTONS
  //────────────────────────────────────────────────────────

  static final OutlinedButtonThemeData _outlinedButtonTheme =
  OutlinedButtonThemeData(
    style: OutlinedButton.styleFrom(
      minimumSize: const Size(
        AppDimensions.buttonMinWidth,
        AppDimensions.buttonMdHeight,
      ),
      foregroundColor: AppColors.primary,
      disabledForegroundColor: AppColors.textDisabled,
      textStyle: AppTypography.buttonMd,
      padding: AppSpacing.buttonInsets,
      side: AppBorders.defaultSide,
      shape: AppRadius.buttonShape,
      animationDuration: AppDurations.button,
    ),
  );

  //────────────────────────────────────────────────────────
  // TEXT BUTTONS
  //────────────────────────────────────────────────────────

  static final TextButtonThemeData _textButtonTheme = TextButtonThemeData(
    style: TextButton.styleFrom(
      foregroundColor: AppColors.primary,
      disabledForegroundColor: AppColors.textDisabled,
      textStyle: AppTypography.buttonMd,
      padding: AppSpacing.buttonInsets,
      shape: AppRadius.buttonShape,
      animationDuration: AppDurations.button,
    ),
  );

  //────────────────────────────────────────────────────────
  // ICONS
  //────────────────────────────────────────────────────────

  static const IconThemeData _iconTheme = IconThemeData(
    color: AppColors.iconPrimary,
    size: AppDimensions.iconMd,
  );

  //────────────────────────────────────────────────────────
  // DIVIDERS
  //────────────────────────────────────────────────────────

  static const DividerThemeData _dividerTheme = DividerThemeData(
    color: AppColors.divider,
    thickness: AppDimensions.dividerThickness,
    space: AppSpacing.lg,
  );

  //────────────────────────────────────────────────────────
  // BOTTOM NAVIGATION
  //────────────────────────────────────────────────────────

  static final BottomNavigationBarThemeData _bottomNavigationBarTheme =
  BottomNavigationBarThemeData(
    elevation: 0,
    backgroundColor: AppColors.surface,
    selectedItemColor: AppColors.primary,
    unselectedItemColor: AppColors.iconTertiary,
    selectedLabelStyle: AppTypography.labelMd,
    unselectedLabelStyle: AppTypography.labelMd,
    type: BottomNavigationBarType.fixed,
  );

  static final NavigationBarThemeData _navigationBarTheme =
  NavigationBarThemeData(
    height: AppDimensions.bottomNavHeight,
    elevation: 0,
    backgroundColor: AppColors.surface,
    indicatorColor: AppColors.primaryLight,
    labelTextStyle: WidgetStateProperty.resolveWith<TextStyle>(
          (states) {
        if (states.contains(WidgetState.selected)) {
          return AppTypography.labelMd.copyWith(
            color: AppColors.primary,
          );
        }

        return AppTypography.labelMd.copyWith(
          color: AppColors.textTertiary,
        );
      },
    ),
    iconTheme: WidgetStateProperty.resolveWith<IconThemeData>(
          (states) {
        if (states.contains(WidgetState.selected)) {
          return const IconThemeData(
            color: AppColors.primary,
            size: AppDimensions.bottomNavIconSize,
          );
        }

        return const IconThemeData(
          color: AppColors.iconTertiary,
          size: AppDimensions.bottomNavIconSize,
        );
      },
    ),
  );

  //────────────────────────────────────────────────────────
  // DIALOGS
  //────────────────────────────────────────────────────────

  static const DialogThemeData _dialogTheme = DialogThemeData(
    elevation: 0,
    backgroundColor: AppColors.surface,
    surfaceTintColor: AppColors.transparent,
    shape: AppRadius.dialogShape,
  );

  //────────────────────────────────────────────────────────
  // BOTTOM SHEETS
  //────────────────────────────────────────────────────────

  static const BottomSheetThemeData _bottomSheetTheme = BottomSheetThemeData(
    elevation: 0,
    backgroundColor: AppColors.surface,
    surfaceTintColor: AppColors.transparent,
    shape: RoundedRectangleBorder(
      borderRadius: AppRadius.sheetRadius,
    ),
  );

  //────────────────────────────────────────────────────────
  // SNACK BAR
  //────────────────────────────────────────────────────────

  static final SnackBarThemeData _snackBarTheme = SnackBarThemeData(
    elevation: 0,
    backgroundColor: AppColors.textPrimary,
    contentTextStyle: AppTypography.bodyMd.copyWith(
      color: AppColors.textInverse,
    ),
    behavior: SnackBarBehavior.floating,
    shape: const RoundedRectangleBorder(
      borderRadius: AppRadius.mdRadius,
    ),
  );

  //────────────────────────────────────────────────────────
  // PAGE TRANSITIONS
  //────────────────────────────────────────────────────────

  static const PageTransitionsTheme _pageTransitionsTheme =
  PageTransitionsTheme(
    builders: <TargetPlatform, PageTransitionsBuilder>{
      TargetPlatform.android: ZoomPageTransitionsBuilder(),
      TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
      TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
    },
  );

  //────────────────────────────────────────────────────────
  // ANIMATION HELPERS
  //────────────────────────────────────────────────────────

  static const Curve defaultCurve = AppCurves.standard;
  static const Duration defaultDuration = AppDurations.normal;
}