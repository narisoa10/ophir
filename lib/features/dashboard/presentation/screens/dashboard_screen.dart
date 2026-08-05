import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/errors/result.dart';
import '../../../../core/theme_v1/app_theme_colors.dart';
import '../../../../core/theme_v1/app_spacing.dart';
import '../../../operations/controller/operation_providers.dart';
import '../../../operations/domain/entities/operation.dart';
import '../widgets/dashboard_categorization_action.dart';
import '../widgets/dashboard_header.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(operationBootstrapProvider);
    final operationsState = ref.watch(operationsProvider);

    return Scaffold(
      backgroundColor: context.appThemeColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: AppSpacing.screen,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const DashboardHeader(),
              operationsState.when(
                loading: () => const SizedBox.shrink(),
                error: (_, stackTrace) => const SizedBox.shrink(),
                data: (result) {
                  final operations = switch (result) {
                    Success<List<Operation>>(:final value) => value,
                    Failure<List<Operation>>() => const <Operation>[],
                  };

                  return DashboardCategorizationAction(operations: operations);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
