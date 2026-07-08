import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/app_routes.dart';
import '../../../../core/errors/result.dart';
import '../../../../core/evaluation/financial_evaluation_context_provider.dart';
import '../../../../core/theme_v1/app_colors.dart';
import '../../../../core/theme_v1/app_spacing.dart';
import '../../../profile/controller/profile_controller.dart';
import '../../../profile/domain/entities/profile.dart';
import '../../domain/services/dashboard_greeting_service.dart';
import '../widgets/dashboard_header.dart';
import '../widgets/dashboard_presentation_builder.dart';
import '../widgets/dashboard_v1_content.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileState = ref.watch(profileControllerProvider);
    final now = ref.watch(financialEvaluationContextProvider).now;
    final dateText = MaterialLocalizations.of(context).formatMediumDate(now);
    final greeting = const DashboardGreetingService().getGreeting(now);
    final profile = _profileFromState(profileState.valueOrNull);

    return ColoredBox(
      color: AppColors.background,
      child: SafeArea(
        child: SingleChildScrollView(
          padding: AppSpacing.dashboardScreenInsets,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              DashboardHeader(
                dateText: dateText,
                greeting: greeting,
                name: profile?.fullName,
                avatarUrl: profile?.avatarUrl,
              ),
              const SizedBox(height: AppSpacing.dashboardSectionGap),
              DashboardPresentationBuilder(
                builder: (context, presentation, l10n) {
                  return DashboardV1Content(
                    presentation: presentation,
                    onFinancialStateDetailTap: () {
                      context.push(AppRoutes.dashboardFinancialState);
                    },
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Profile? _profileFromState(Result<Profile>? result) {
    return switch (result) {
      Success<Profile>(:final value) => value,
      Failure<Profile>() => null,
      null => null,
    };
  }
}
