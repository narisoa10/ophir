import 'package:flutter/material.dart';

import '../theme_v1/app_theme_colors.dart';
import '../theme_v1/app_radius.dart';

InputDecoration appFormFieldDecoration(
  BuildContext context, {
  required String labelText,
}) {
  final colors = context.appThemeColors;

  return InputDecoration(
    labelText: labelText,
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
