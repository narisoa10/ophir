import 'package:flutter/material.dart';

import '../../../../core/theme_v1/app_spacing.dart';
import '../../../../core/theme_v1/app_theme_colors.dart';
import '../../../../core/theme_v1/app_typography.dart';

class SettingsScaffold extends StatelessWidget {
  const SettingsScaffold({
    required this.title,
    this.children = const [],
    this.body,
    this.showAppBar = true,
    this.actions,
    super.key,
  });

  final String title;
  final List<Widget> children;
  final Widget? body;
  final bool showAppBar;
  final List<Widget>? actions;

  @override
  Widget build(BuildContext context) {
    final colors = context.appThemeColors;

    return Scaffold(
      backgroundColor: colors.background,
      appBar: showAppBar
          ? AppBar(
              backgroundColor: colors.background,
              foregroundColor: colors.textPrimary,
              actions: actions,
              title: Text(
                title,
                style: AppTypography.bodyStrong.copyWith(
                  color: colors.textPrimary,
                ),
              ),
            )
          : null,
      body:
          body ??
          _SettingsScaffoldList(
            title: title,
            showTitle: !showAppBar,
            children: children,
          ),
    );
  }
}

class _SettingsScaffoldList extends StatelessWidget {
  const _SettingsScaffoldList({
    required this.title,
    required this.showTitle,
    required this.children,
  });

  final String title;
  final bool showTitle;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final colors = context.appThemeColors;

    return ListView(
      padding: AppSpacing.screen,
      children: [
        if (showTitle) ...[
          Text(
            title,
            style: AppTypography.screenTitle.copyWith(
              color: colors.textPrimary,
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
        ],
        ...children,
      ],
    );
  }
}
