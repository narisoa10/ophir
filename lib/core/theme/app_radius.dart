import 'package:flutter/material.dart';

abstract final class AppRadius {
  AppRadius._();

  //────────────────────────────────────────────────────────
  // BASE
  //────────────────────────────────────────────────────────

  static const double none = 0;

  //────────────────────────────────────────────────────────
  // SCALE
  //────────────────────────────────────────────────────────

  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 20;
  static const double xxl = 24;
  static const double pill = 999;

  //────────────────────────────────────────────────────────
  // COMPONENTS
  //────────────────────────────────────────────────────────

  static const double button = lg;
  static const double input = lg;
  static const double card = xl;
  static const double sheet = xxl;
  static const double dialog = xxl;
  static const double badge = pill;
  static const double avatar = pill;

  //────────────────────────────────────────────────────────
  // BORDER RADIUS
  //────────────────────────────────────────────────────────

  static const BorderRadius zero = BorderRadius.zero;

  static const BorderRadius xsRadius = BorderRadius.all(
    Radius.circular(xs),
  );

  static const BorderRadius smRadius = BorderRadius.all(
    Radius.circular(sm),
  );

  static const BorderRadius mdRadius = BorderRadius.all(
    Radius.circular(md),
  );

  static const BorderRadius lgRadius = BorderRadius.all(
    Radius.circular(lg),
  );

  static const BorderRadius xlRadius = BorderRadius.all(
    Radius.circular(xl),
  );

  static const BorderRadius xxlRadius = BorderRadius.all(
    Radius.circular(xxl),
  );

  static const BorderRadius pillRadius = BorderRadius.all(
    Radius.circular(pill),
  );

  //────────────────────────────────────────────────────────
  // COMPONENT BORDER RADIUS
  //────────────────────────────────────────────────────────

  static const BorderRadius buttonRadius = BorderRadius.all(
    Radius.circular(button),
  );

  static const BorderRadius inputRadius = BorderRadius.all(
    Radius.circular(input),
  );

  static const BorderRadius cardRadius = BorderRadius.all(
    Radius.circular(card),
  );

  static const BorderRadius sheetRadius = BorderRadius.vertical(
    top: Radius.circular(sheet),
  );

  static const BorderRadius dialogRadius = BorderRadius.all(
    Radius.circular(dialog),
  );

  static const BorderRadius badgeRadius = BorderRadius.all(
    Radius.circular(badge),
  );

  //────────────────────────────────────────────────────────
  // ROUNDED RECTANGLE BORDERS
  //────────────────────────────────────────────────────────

  static const RoundedRectangleBorder buttonShape = RoundedRectangleBorder(
    borderRadius: buttonRadius,
  );

  static const RoundedRectangleBorder inputShape = RoundedRectangleBorder(
    borderRadius: inputRadius,
  );

  static const RoundedRectangleBorder cardShape = RoundedRectangleBorder(
    borderRadius: cardRadius,
  );

  static const RoundedRectangleBorder dialogShape = RoundedRectangleBorder(
    borderRadius: dialogRadius,
  );
}