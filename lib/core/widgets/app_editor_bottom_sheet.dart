import 'package:flutter/material.dart';

import '../theme_v1/app_theme_colors.dart';
import '../theme_v1/app_dimensions.dart';
import '../theme_v1/app_spacing.dart';
import '../theme_v1/app_typography.dart';

class AppEditorBottomSheet extends StatelessWidget {
  const AppEditorBottomSheet({
    super.key,
    required this.title,
    required this.child,
    required this.onSave,
    required this.saveLabel,
    this.formKey,
    this.onDelete,
    this.deleteLabel,
  });

  final String title;
  final Widget child;
  final VoidCallback onSave;
  final String saveLabel;
  final GlobalKey<FormState>? formKey;
  final VoidCallback? onDelete;
  final String? deleteLabel;

  @override
  Widget build(BuildContext context) {
    final content = SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: AppTypography.sectionTitle),
          const SizedBox(height: AppSpacing.itemGap),
          child,
          const SizedBox(height: AppSpacing.screenGap),
          Row(
            children: [
              if (onDelete != null)
                TextButton(onPressed: onDelete, child: Text(deleteLabel ?? '')),
              const Spacer(),
              ElevatedButton(
                onPressed: onSave,
                style: ElevatedButton.styleFrom(
                  backgroundColor: context.appThemeColors.primary,
                  foregroundColor: context.appThemeColors.textInverse,
                  minimumSize: const Size(
                    AppDimensions.buttonMinWidth,
                    AppDimensions.buttonMdHeight,
                  ),
                  padding: AppSpacing.buttonInsets,
                ),
                child: Text(saveLabel),
              ),
            ],
          ),
        ],
      ),
    );

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: AppSpacing.lg,
          right: AppSpacing.lg,
          top: AppSpacing.lg,
          bottom: MediaQuery.of(context).viewInsets.bottom + AppSpacing.lg,
        ),
        child: formKey == null ? content : Form(key: formKey, child: content),
      ),
    );
  }
}
