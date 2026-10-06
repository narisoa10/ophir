import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ophir/core/localization/generated/app_localizations.dart';

void main() {
  final l10n = lookupAppLocalizations(const Locale('fr'));

  test('French plural "one" covers 0 and 1 with the actual count', () {
    expect(l10n.accountsInstitutionAccountCount(0), '0 compte');
    expect(l10n.accountsInstitutionAccountCount(1), '1 compte');
    expect(l10n.accountsInstitutionAccountCount(2), '2 comptes');

    expect(
      l10n.accountsAmbiguousConnectionDialogMoreCandidates(0),
      'et 0 autre compte semblable',
    );
    expect(
      l10n.accountsAmbiguousConnectionDialogMoreCandidates(1),
      'et 1 autre compte semblable',
    );
    expect(
      l10n.accountsAmbiguousConnectionDialogMoreCandidates(2),
      'et 2 autres comptes semblables',
    );

    expect(l10n.operationsReviewBanner(0), '0 à catégoriser');
    expect(l10n.operationsReviewBanner(1), '1 à catégoriser');
    expect(l10n.operationsReviewBanner(2), '2 à catégoriser');
  });
}
