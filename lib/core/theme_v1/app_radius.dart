import 'package:flutter/material.dart';

abstract final class AppRadius {
  AppRadius._();

  static const double sm = 8;
  static const double lg = 16;
  static const double xl = 20;

  static const BorderRadius smRadius = BorderRadius.all(Radius.circular(sm));

  static const BorderRadius inputRadius = BorderRadius.all(Radius.circular(lg));

  static const BorderRadius cardRadius = BorderRadius.all(Radius.circular(xl));

  static const RoundedRectangleBorder inputShape = RoundedRectangleBorder(
    borderRadius: inputRadius,
  );

  static const RoundedRectangleBorder buttonShape = RoundedRectangleBorder(
    borderRadius: inputRadius,
  );

  static const RoundedRectangleBorder cardShape = RoundedRectangleBorder(
    borderRadius: cardRadius,
  );
}
