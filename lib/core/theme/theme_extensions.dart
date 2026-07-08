import 'package:flutter/material.dart';

import 'app_colors.dart';

@immutable
final class AppThemeExtension extends ThemeExtension<AppThemeExtension> {
  const AppThemeExtension({
    required this.balanceGradient,
    required this.incomeGradient,
    required this.expenseGradient,
    required this.aiGradient,
    required this.chartPalette,
  });

  //────────────────────────────────────────────────────────
  // GRADIENTS
  //────────────────────────────────────────────────────────

  final LinearGradient balanceGradient;
  final LinearGradient incomeGradient;
  final LinearGradient expenseGradient;
  final LinearGradient aiGradient;

  //────────────────────────────────────────────────────────
  // CHARTS
  //────────────────────────────────────────────────────────

  final List<Color> chartPalette;

  //────────────────────────────────────────────────────────
  // LIGHT
  //────────────────────────────────────────────────────────

  static const AppThemeExtension light = AppThemeExtension(
    balanceGradient: LinearGradient(
      colors: <Color>[
        AppColors.primary,
        AppColors.primaryDark,
      ],
    ),
    incomeGradient: LinearGradient(
      colors: <Color>[
        AppColors.success,
        AppColors.successDark,
      ],
    ),
    expenseGradient: LinearGradient(
      colors: <Color>[
        AppColors.error,
        AppColors.errorDark,
      ],
    ),
    aiGradient: LinearGradient(
      colors: <Color>[
        AppColors.surfacePurple,
        AppColors.surfaceOrange,
      ],
    ),
    chartPalette: AppColors.chartPalette,
  );

  //────────────────────────────────────────────────────────
  // COPY WITH
  //────────────────────────────────────────────────────────

  @override
  AppThemeExtension copyWith({
    LinearGradient? balanceGradient,
    LinearGradient? incomeGradient,
    LinearGradient? expenseGradient,
    LinearGradient? aiGradient,
    List<Color>? chartPalette,
  }) {
    return AppThemeExtension(
      balanceGradient: balanceGradient ?? this.balanceGradient,
      incomeGradient: incomeGradient ?? this.incomeGradient,
      expenseGradient: expenseGradient ?? this.expenseGradient,
      aiGradient: aiGradient ?? this.aiGradient,
      chartPalette: chartPalette ?? this.chartPalette,
    );
  }

  //────────────────────────────────────────────────────────
  // LERP
  //────────────────────────────────────────────────────────

  @override
  AppThemeExtension lerp(
      covariant ThemeExtension<AppThemeExtension>? other,
      double t,
      ) {
    if (other is! AppThemeExtension) {
      return this;
    }

    return AppThemeExtension(
      balanceGradient: LinearGradient.lerp(
        balanceGradient,
        other.balanceGradient,
        t,
      ) ??
          balanceGradient,
      incomeGradient: LinearGradient.lerp(
        incomeGradient,
        other.incomeGradient,
        t,
      ) ??
          incomeGradient,
      expenseGradient: LinearGradient.lerp(
        expenseGradient,
        other.expenseGradient,
        t,
      ) ??
          expenseGradient,
      aiGradient: LinearGradient.lerp(
        aiGradient,
        other.aiGradient,
        t,
      ) ??
          aiGradient,
      chartPalette: _lerpColorList(
        chartPalette,
        other.chartPalette,
        t,
      ),
    );
  }

  //────────────────────────────────────────────────────────
  // HELPERS
  //────────────────────────────────────────────────────────

  static List<Color> _lerpColorList(
      List<Color> a,
      List<Color> b,
      double t,
      ) {
    final int length = a.length < b.length ? a.length : b.length;

    return List<Color>.generate(
      length,
          (index) => Color.lerp(a[index], b[index], t) ?? a[index],
      growable: false,
    );
  }
}

extension AppThemeExtensionX on BuildContext {
  AppThemeExtension get appTheme {
    return Theme.of(this).extension<AppThemeExtension>() ??
        AppThemeExtension.light;
  }
}