abstract final class AppDurations {
  AppDurations._();

  //────────────────────────────────────────────────────────
  // INSTANT
  //────────────────────────────────────────────────────────

  static const Duration none = Duration.zero;
  static const Duration instant = Duration(milliseconds: 50);

  //────────────────────────────────────────────────────────
  // FAST
  //────────────────────────────────────────────────────────

  static const Duration veryFast = Duration(milliseconds: 100);
  static const Duration fast = Duration(milliseconds: 150);

  //────────────────────────────────────────────────────────
  // NORMAL
  //────────────────────────────────────────────────────────

  static const Duration normal = Duration(milliseconds: 250);
  static const Duration medium = Duration(milliseconds: 300);

  //────────────────────────────────────────────────────────
  // SLOW
  //────────────────────────────────────────────────────────

  static const Duration slow = Duration(milliseconds: 500);
  static const Duration verySlow = Duration(milliseconds: 700);

  //────────────────────────────────────────────────────────
  // COMPONENTS
  //────────────────────────────────────────────────────────

  static const Duration button = fast;
  static const Duration dialog = medium;
  static const Duration bottomSheet = medium;
  static const Duration snackbar = medium;
  static const Duration tooltip = fast;

  static const Duration pageTransition = medium;
  static const Duration navigation = medium;

  static const Duration fade = fast;
  static const Duration scale = fast;
  static const Duration slide = medium;
  static const Duration size = medium;

  static const Duration loading = slow;
  static const Duration shimmer = Duration(milliseconds: 1200);
}