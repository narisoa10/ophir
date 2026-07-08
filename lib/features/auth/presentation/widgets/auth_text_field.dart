import 'package:flutter/material.dart';

import '../../../../core/theme/app_dimensions.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';

class AuthTextField extends StatelessWidget {
  const AuthTextField({
    required this.controller,
    required this.hintText,
    this.keyboardType,
    this.obscureText = false,
    this.suffixIcon,
    this.onSuffixTap,
    this.onChanged,
    super.key,
  });

  final TextEditingController controller;
  final String hintText;
  final TextInputType? keyboardType;
  final bool obscureText;
  final String? suffixIcon;
  final VoidCallback? onSuffixTap;
  final ValueChanged<String>? onChanged;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: AppDimensions.inputLgHeight,
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        obscureText: obscureText,
        onChanged: onChanged,
        style: AppTypography.bodyMd,
        decoration: InputDecoration(
          hintText: hintText,
          suffixIcon: suffixIcon == null
              ? null
              : GestureDetector(
            onTap: onSuffixTap,
            behavior: HitTestBehavior.opaque,
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Image.asset(
                suffixIcon!,
                width: AppDimensions.iconSm,
                height: AppDimensions.iconSm,
                fit: BoxFit.contain,
              ),
            ),
          ),
        ),
      ),
    );
  }
}