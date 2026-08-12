import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme_v1/app_theme_colors.dart';
import '../../features/operations/controller/operation_providers.dart';
import 'app_bottom_navigation_bar.dart';

class AppShell extends ConsumerStatefulWidget {
  const AppShell({required this.child, super.key});

  final Widget child;

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) {
      return;
    }

    unawaited(_refreshOperationsOnResume());
  }

  Future<void> _refreshOperationsOnResume() async {
    try {
      await ref.read(operationRemoteSyncProvider)();
    } catch (_) {
      // Background resume refresh must remain non-destructive.
    }
  }

  @override
  Widget build(BuildContext context) {
    final location = GoRouterState.of(context).uri.path;

    return Scaffold(
      backgroundColor: context.appThemeColors.background,
      body: SafeArea(child: widget.child),
      bottomNavigationBar: AppBottomNavigationBar(currentLocation: location),
    );
  }
}
