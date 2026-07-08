abstract final class AppOpacity {
  AppOpacity._();

  //────────────────────────────────────────────────────────
  // TRANSPARENCY
  //────────────────────────────────────────────────────────

  static const double transparent = 0.00;
  static const double almostTransparent = 0.05;
  static const double veryLow = 0.08;
  static const double low = 0.12;
  static const double light = 0.16;
  static const double medium = 0.24;
  static const double strong = 0.38;
  static const double heavy = 0.54;
  static const double veryHeavy = 0.72;
  static const double almostOpaque = 0.87;
  static const double opaque = 1.00;

  //────────────────────────────────────────────────────────
  // COMPONENT STATES
  //────────────────────────────────────────────────────────

  /// Disabled buttons, icons, text.
  static const double disabled = 0.38;

  /// Read-only widgets.
  static const double readOnly = 0.60;

  /// Hover effect.
  static const double hover = 0.08;

  /// Pressed state.
  static const double pressed = 0.12;

  /// Focus highlight.
  static const double focused = 0.12;

  /// Selected item overlay.
  static const double selected = 0.16;

  /// Drag feedback.
  static const double dragging = 0.16;

  //────────────────────────────────────────────────────────
  // OVERLAYS
  //────────────────────────────────────────────────────────

  /// Dialogs / BottomSheets background.
  static const double scrim = 0.54;

  /// Modal barrier.
  static const double modalBarrier = 0.54;

  /// Image overlay.
  static const double imageOverlay = 0.32;

  /// Loading overlay.
  static const double loading = 0.60;

  //────────────────────────────────────────────────────────
  // EFFECTS
  //────────────────────────────────────────────────────────

  /// Shimmer effect.
  static const double shimmer = 0.20;

  /// Skeleton loaders.
  static const double skeleton = 0.15;

  /// Shadows multiplier.
  static const double shadow = 0.18;

  /// Glass / Frosted effect.
  static const double glass = 0.10;
}