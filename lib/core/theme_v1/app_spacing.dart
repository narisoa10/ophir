import 'package:flutter/material.dart';

abstract final class AppSpacing {
  AppSpacing._();

  static const double none = 0;
  static const double hairline = 2;
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 20;
  static const double xxxl = 32;

  static const double inlineGap = sm;
  static const double itemGap = lg;
  static const double sectionGap = md;
  static const double screenGap = xl;
  static const double settingsSectionGap = sm;
  static const double categoryChipGap = xs;
  static const double categorySectionGap = md;
  static const double categoryHeaderGap = xs;

  static const EdgeInsets screen = EdgeInsets.symmetric(
    horizontal: xl,
    vertical: xl,
  );

  static const EdgeInsets dashboardScreenInsets = EdgeInsets.symmetric(
    horizontal: md,
    vertical: sm,
  );

  static const EdgeInsets noneInsets = EdgeInsets.all(none);

  static const EdgeInsets cardInsets = EdgeInsets.all(lg);

  static const EdgeInsets compactCardInsets = EdgeInsets.all(sm);

  static const EdgeInsets financialStatePeriodInsets = EdgeInsets.fromLTRB(
    sm,
    none,
    sm,
    sm,
  );

  static const double dashboardSectionGap = sm;
  static const double financialStateItemGap = xs;
  static const double financialStateContentGap = xs;
  static const double financialStateBlockGap = sm;

  static const EdgeInsets financialStateButtonInsets = EdgeInsets.symmetric(
    horizontal: md,
    vertical: xs,
  );

  static const EdgeInsets listTileInsets = EdgeInsets.symmetric(
    horizontal: md,
    vertical: sm,
  );

  static const EdgeInsets listItemBottomGap = EdgeInsets.only(bottom: sm);

  static const EdgeInsets compactListTileInsets = EdgeInsets.symmetric(
    horizontal: xs,
    vertical: xs,
  );

  static const EdgeInsets settingsTileInsets = EdgeInsets.symmetric(
    horizontal: md,
    vertical: sm,
  );

  static const EdgeInsets settingsHeaderInsets = EdgeInsets.symmetric(
    horizontal: lg,
    vertical: md,
  );

  static const EdgeInsets settingsSectionHeaderInsets = EdgeInsets.symmetric(
    horizontal: md,
    vertical: hairline,
  );

  static const EdgeInsets categoryPickerScreenInsets = EdgeInsets.symmetric(
    horizontal: md,
    vertical: sm,
  );

  static const EdgeInsets categoryPickerSectionInsets = EdgeInsets.symmetric(
    horizontal: none,
    vertical: xs,
  );

  static const EdgeInsets categoryPickerChipInsets = EdgeInsets.symmetric(
    horizontal: sm,
    vertical: xs,
  );

  static const EdgeInsets buttonInsets = EdgeInsets.symmetric(
    horizontal: xl,
    vertical: md,
  );

  static const EdgeInsets sectionHeaderInsets = EdgeInsets.symmetric(
    horizontal: md,
    vertical: xs,
  );
}
