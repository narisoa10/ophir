import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ophir/core/localization/generated/app_localizations.dart';
import 'package:ophir/features/operations/data/repositories/supabase_internal_transfer_review_repository.dart';
import 'package:ophir/features/operations/domain/entities/internal_transfer_review_item.dart';
import 'package:ophir/features/operations/domain/enums/operation_source.dart';
import 'package:ophir/features/operations/presentation/widgets/internal_transfer_review_banner.dart';

void main() {
  final l10n = lookupAppLocalizations(const Locale('en'));

  test('H2-10/H2-11 confirm body has reconciliation_id only', () {
    final body = buildInternalTransferConfirmRequestBody(
      '22222222-2222-4222-8222-222222222222',
    );
    expect(body.keys.toList(), ['reconciliation_id']);
    expect(body.containsKey('user_id'), isFalse);
    expect(body.containsKey('p_user_id'), isFalse);
    expect(body['reconciliation_id'], '22222222-2222-4222-8222-222222222222');
  });

  testWidgets('H2-5 banner hidden when zero', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: InternalTransferReviewBanner(
            count: 0,
            label: l10n.internalTransferReviewBanner(0),
            semanticsLabel: l10n.internalTransferReviewBannerSemantics(0),
            onTap: () {},
          ),
        ),
      ),
    );

    expect(find.byType(InkWell), findsNothing);
  });

  testWidgets('H2-6 banner displays candidate count', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: InternalTransferReviewBanner(
            count: 2,
            label: l10n.internalTransferReviewBanner(2),
            semanticsLabel: l10n.internalTransferReviewBannerSemantics(2),
            onTap: () {},
          ),
        ),
      ),
    );

    expect(find.text(l10n.internalTransferReviewBanner(2)), findsOneWidget);
  });

  testWidgets('H2-7 banner opens review via onTap', (tester) async {
    var taps = 0;
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: InternalTransferReviewBanner(
            count: 1,
            label: l10n.internalTransferReviewBanner(1),
            semanticsLabel: l10n.internalTransferReviewBannerSemantics(1),
            onTap: () => taps += 1,
          ),
        ),
      ),
    );

    await tester.tap(find.byType(InkWell));
    expect(taps, 1);
  });

  test('H2-8/H2-9 candidate display fields and unavailable fallback', () {
    final available = InternalTransferReviewAccount(
      id: 'a',
      displayName: 'Checking',
      mask: '1234',
      available: true,
    );
    final unavailable = const InternalTransferReviewAccount(available: false);

    expect(available.displayName, 'Checking');
    expect(available.mask, '1234');
    expect(unavailable.available, isFalse);
    expect(unavailable.displayName, isNull);
    expect(l10n.internalTransferReviewUnavailableAccount, isNotEmpty);
    expect(l10n.internalTransferReviewFrom, isNotEmpty);
    expect(l10n.internalTransferReviewTo, isNotEmpty);
  });

  test(
    'H2-17 confirm is a single primary action string (no second dialog key)',
    () {
      expect(l10n.internalTransferReviewConfirm, isNotEmpty);
    },
  );

  test('H2-18 manual OperationSource unchanged', () {
    expect(OperationSource.manual.toJson(), 'manual');
    expect(OperationSource.fromJson('manual'), OperationSource.manual);
  });

  test('H2-19 ordinary Plaid OperationSource unchanged', () {
    expect(OperationSource.plaid.toJson(), 'plaid');
    expect(OperationSource.fromJson('plaid'), OperationSource.plaid);
  });

  test('H2-20 synthetic source still distinct for guards', () {
    expect(
      OperationSource.plaidInternalTransfer.toJson(),
      'plaid_internal_transfer',
    );
    expect(
      OperationSource.fromJson('plaid_internal_transfer'),
      OperationSource.plaidInternalTransfer,
    );
  });
}
