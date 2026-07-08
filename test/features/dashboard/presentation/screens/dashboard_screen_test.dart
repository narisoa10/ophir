import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ophir/core/errors/app_failure.dart';
import 'package:ophir/core/errors/result.dart';
import 'package:ophir/core/evaluation/evaluation_clock.dart';
import 'package:ophir/core/evaluation/financial_evaluation_context_provider.dart';
import 'package:ophir/core/localization/generated/app_localizations.dart';
import 'package:ophir/features/assistant/controller/assistant_dashboard_briefing_provider.dart';
import 'package:ophir/features/dashboard/presentation/screens/dashboard_screen.dart';
import 'package:ophir/features/profile/controller/profile_providers.dart';
import 'package:ophir/features/profile/domain/entities/profile.dart';
import 'package:ophir/features/profile/domain/repositories/profile_repository.dart';

void main() {
  group('DashboardScreen', () {
    testWidgets('uses shared clock for header date and greeting', (
      tester,
    ) async {
      final fixedNow = DateTime(2030, 5, 10, 6, 30);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            evaluationClockProvider.overrideWithValue(
              EvaluationClock(fixedNow: fixedNow),
            ),
            profileRepositoryProvider.overrideWithValue(
              _FakeProfileRepository(profile: _profile()),
            ),
            assistantDashboardBriefingProvider.overrideWith(
              (ref) async => const Failure(UnknownFailure()),
            ),
          ],
          child: const MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: DashboardScreen(),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Fri, May 10'), findsOneWidget);
      expect(find.text('Good morning, Ada'), findsOneWidget);
    });

    test('does not create DateTime.now inside dashboard feature', () {
      final dashboardFiles = Directory('lib/features/dashboard')
          .listSync(recursive: true)
          .whereType<File>()
          .where((file) => file.path.endsWith('.dart'));

      for (final file in dashboardFiles) {
        expect(
          file.readAsStringSync(),
          isNot(contains('DateTime.now()')),
          reason: file.path,
        );
      }
    });
  });
}

final class _FakeProfileRepository implements ProfileRepository {
  const _FakeProfileRepository({required this.profile});

  final Profile profile;

  @override
  Future<Result<Profile>> getCurrentProfile() async {
    return Success(profile);
  }

  @override
  Future<Result<Profile>> updateProfile(Profile profile) async {
    return Success(profile);
  }

  @override
  Stream<Result<Profile>> watchCurrentProfile() {
    return Stream.value(Success(profile));
  }
}

Profile _profile() {
  final now = DateTime.utc(2026);

  return Profile(
    id: 'profile',
    email: 'ada@example.com',
    fullName: 'Ada',
    locale: 'en',
    currencyCode: 'CAD',
    timezone: 'America/Toronto',
    onboardingCompleted: true,
    createdAt: now,
    updatedAt: now,
  );
}
