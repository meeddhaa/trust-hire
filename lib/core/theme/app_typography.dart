import 'package:flutter/material.dart';

/// Type scale for the "Ember" redesign — matches the user-supplied dark
/// photo-card reference's bold, all-sans headline language (its "Let's
/// Find Your Next Job" is a heavy grotesk, not a serif).
///
/// Fraunces (serif) is now reserved for ONLY the match-score numeral
/// itself ([displayLarge]/[displayMedium]/[displaySmall]) — the one
/// number in the app meant to read as a considered verdict rather than a
/// UI label. Every headline/section-title role that used to carry Fraunces
/// under "Editorial Trust" now uses Manrope at a heavier weight instead,
/// matching the reference.
abstract final class AppTypography {
  static const String display = 'Fraunces';
  static const String ui = 'Manrope';

  static TextTheme textTheme(Color ink, Color inkMuted) {
    return TextTheme(
      // Match-score numerals / hero verdict figures.
      displayLarge: TextStyle(
        fontFamily: display,
        fontSize: 64,
        height: 1.0,
        fontWeight: FontWeight.w600,
        letterSpacing: -1.5,
        color: ink,
      ),
      displayMedium: TextStyle(
        fontFamily: display,
        fontSize: 44,
        height: 1.05,
        fontWeight: FontWeight.w600,
        letterSpacing: -1.0,
        color: ink,
      ),
      displaySmall: TextStyle(
        fontFamily: display,
        fontSize: 32,
        height: 1.1,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.5,
        color: ink,
      ),

      // Trust badge headline / screen section titles — bold Manrope, not
      // Fraunces, per the reference's headline style (see class doc).
      headlineLarge: TextStyle(
        fontFamily: ui,
        fontSize: 28,
        height: 1.15,
        fontWeight: FontWeight.w800,
        letterSpacing: -0.5,
        color: ink,
      ),
      headlineMedium: TextStyle(
        fontFamily: ui,
        fontSize: 22,
        height: 1.2,
        fontWeight: FontWeight.w800,
        letterSpacing: -0.3,
        color: ink,
      ),
      headlineSmall: TextStyle(
        fontFamily: ui,
        fontSize: 18,
        height: 1.25,
        fontWeight: FontWeight.w700,
        color: ink,
      ),

      // Card titles, list item titles.
      titleLarge: TextStyle(
        fontFamily: ui,
        fontSize: 18,
        height: 1.3,
        fontWeight: FontWeight.w700,
        color: ink,
      ),
      titleMedium: TextStyle(
        fontFamily: ui,
        fontSize: 16,
        height: 1.3,
        fontWeight: FontWeight.w700,
        color: ink,
      ),
      titleSmall: TextStyle(
        fontFamily: ui,
        fontSize: 14,
        height: 1.3,
        fontWeight: FontWeight.w700,
        color: ink,
      ),

      // Body copy.
      bodyLarge: TextStyle(
        fontFamily: ui,
        fontSize: 16,
        height: 1.5,
        fontWeight: FontWeight.w400,
        color: ink,
      ),
      bodyMedium: TextStyle(
        fontFamily: ui,
        fontSize: 14,
        height: 1.5,
        fontWeight: FontWeight.w400,
        color: ink,
      ),
      bodySmall: TextStyle(
        fontFamily: ui,
        fontSize: 12,
        height: 1.45,
        fontWeight: FontWeight.w400,
        color: inkMuted,
      ),

      // Labels, buttons, tags, chips.
      labelLarge: TextStyle(
        fontFamily: ui,
        fontSize: 14,
        height: 1.2,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.1,
        color: ink,
      ),
      labelMedium: TextStyle(
        fontFamily: ui,
        fontSize: 12,
        height: 1.2,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.2,
        color: inkMuted,
      ),
      labelSmall: TextStyle(
        fontFamily: ui,
        fontSize: 11,
        height: 1.2,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.3,
        color: inkMuted,
      ),
    );
  }
}
