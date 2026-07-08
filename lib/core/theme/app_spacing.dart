import 'package:flutter/widgets.dart';

abstract final class AppSpacing {
  AppSpacing._();

  //────────────────────────────────────────────────────────
  // BASE
  //────────────────────────────────────────────────────────

  static const double none = 0;

  //────────────────────────────────────────────────────────
  // SCALE
  //────────────────────────────────────────────────────────

  static const double xxs = 2;
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 20;
  static const double xxl = 24;
  static const double xxxl = 32;
  static const double huge = 40;
  static const double massive = 48;
  static const double giant = 64;

  //────────────────────────────────────────────────────────
  // SCREEN
  //────────────────────────────────────────────────────────

  static const double screenHorizontal = 20;
  static const double screenVertical = 20;

  //────────────────────────────────────────────────────────
  // SECTIONS
  //────────────────────────────────────────────────────────

  static const double section = 24;
  static const double card = 16;
  static const double item = 12;

  //────────────────────────────────────────────────────────
  // LISTS
  //────────────────────────────────────────────────────────

  static const double listHorizontal = 16;
  static const double listVertical = 12;

  //────────────────────────────────────────────────────────
  // CONTENT
  //────────────────────────────────────────────────────────

  static const double cardPadding = 16;
  static const double contentSpacing = 12;

  //────────────────────────────────────────────────────────
  // INPUTS
  //────────────────────────────────────────────────────────

  static const double inputHorizontal = 16;
  static const double inputVertical = 14;

  //────────────────────────────────────────────────────────
  // BUTTONS
  //────────────────────────────────────────────────────────

  static const double buttonHorizontal = 20;
  static const double buttonVertical = 14;

  //────────────────────────────────────────────────────────
  // SAFE AREA
  //────────────────────────────────────────────────────────

  static const double bottomInset = 24;

  //────────────────────────────────────────────────────────
  // EDGE INSETS
  //────────────────────────────────────────────────────────

  static const EdgeInsets zero = EdgeInsets.zero;

  static const EdgeInsets screen = EdgeInsets.symmetric(
    horizontal: screenHorizontal,
    vertical: screenVertical,
  );

  static const EdgeInsets screenHorizontalOnly = EdgeInsets.symmetric(
    horizontal: screenHorizontal,
  );

  static const EdgeInsets screenVerticalOnly = EdgeInsets.symmetric(
    vertical: screenVertical,
  );

  static const EdgeInsets cardInsets = EdgeInsets.all(
    cardPadding,
  );

  static const EdgeInsets inputInsets = EdgeInsets.symmetric(
    horizontal: inputHorizontal,
    vertical: inputVertical,
  );

  static const EdgeInsets buttonInsets = EdgeInsets.symmetric(
    horizontal: buttonHorizontal,
    vertical: buttonVertical,
  );
}