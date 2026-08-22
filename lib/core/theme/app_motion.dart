import 'package:flutter/animation.dart';

/// Motion tokens for "Editorial Trust": confident, not bouncy. Nothing
/// springy/playful — this is a trust product, not a game. Reveals settle
/// decisively; nothing overshoots except the deliberate "stamp" used for a
/// verdict landing (trust badge), which is the one place a touch of
/// physicality is earned.
abstract final class AppMotion {
  // --- Durations ---
  static const Duration fast = Duration(milliseconds: 150);
  static const Duration standard = Duration(milliseconds: 300);
  static const Duration slow = Duration(milliseconds: 500);

  /// Radial arc draw + digit count-up on the match score.
  static const Duration scoreReveal = Duration(milliseconds: 900);

  /// Hold-then-stamp reveal of the trust badge.
  static const Duration badgeReveal = Duration(milliseconds: 500);
  static const Duration badgeHold = Duration(milliseconds: 200);

  /// Per-item delay for staggered feed entrance.
  static const Duration feedStagger = Duration(milliseconds: 60);

  // --- Curves ---

  /// Default "resistance-then-settle" for cards, feed entrance, expand/
  /// collapse of the gap breakdown. Decelerates without overshoot.
  static const Curve settle = Curves.easeOutCubic;

  /// Confident, slightly slower deceleration for the score arc draw —
  /// reads as "arriving at a conclusion" rather than a generic ease-out.
  static const Curve arc = Curves.easeOutQuint;

  /// The one place we allow overshoot: a quick, decisive stamp landing for
  /// the trust badge reveal. Tuned shallow on purpose — a thud, not a bounce.
  static const Curve stamp = Cubic(0.34, 1.35, 0.64, 1.0);
}
