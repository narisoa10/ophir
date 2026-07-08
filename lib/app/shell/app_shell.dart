import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme_v1/app_colors.dart';
import 'app_bottom_navigation_bar.dart';

class AppShell extends StatelessWidget {
  const AppShell({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final location = GoRouterState.of(context).uri.path;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(child: child),
      bottomNavigationBar: AppBottomNavigationBar(currentLocation: location),
    );
  }
}
