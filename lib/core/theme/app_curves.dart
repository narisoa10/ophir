import 'package:flutter/material.dart';

abstract final class AppCurves {
  AppCurves._();

  //────────────────────────────────────────────────────────
  // STANDARD
  //────────────────────────────────────────────────────────

  static const Curve linear = Curves.linear;
  static const Curve standard = Curves.easeInOut;
  static const Curve emphasized = Curves.easeInOutCubic;

  //────────────────────────────────────────────────────────
  // ENTRANCE
  //────────────────────────────────────────────────────────

  static const Curve enter = Curves.easeOut;
  static const Curve enterSoft = Curves.easeOutCubic;
  static const Curve enterSharp = Curves.easeOutExpo;

  //────────────────────────────────────────────────────────
  // EXIT
  //────────────────────────────────────────────────────────

  static const Curve exit = Curves.easeIn;
  static const Curve exitSoft = Curves.easeInCubic;
  static const Curve exitSharp = Curves.easeInExpo;

  //────────────────────────────────────────────────────────
  // COMPONENTS
  //────────────────────────────────────────────────────────

  static const Curve button = enterSoft;
  static const Curve dialog = emphasized;
  static const Curve bottomSheet = emphasized;
  static const Curve pageTransition = emphasized;
  static const Curve navigation = emphasized;

  static const Curve fade = standard;
  static const Curve scale = enterSoft;
  static const Curve slide = enterSoft;
  static const Curve size = emphasized;
}