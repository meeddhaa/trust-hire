import 'package:flutter/material.dart';

/// Type scale for "Editorial Trust".
///
/// Fraunces (serif) is reserved for the things that carry a judgment —
/// match-score numerals, trust-badge headlines, section titles that read
/// as a verdict. Manrope (grotesk) carries everything else: lists, labels,
/// body copy, form fields. The pairing is what makes a score feel like a
/// considered assessment rather than a UI widget spitting out a number.
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

      // Trust badge headline / screen section titles.
      headlineLarge: TextStyle(
        fontFamily: display,
        fontSize: 28,
        height: 1.15,
        fontWeight: FontWeight.w500,
        color: ink,
      ),
      headlineMedium: TextStyle(
        fontFamily: display,
        fontSize: 22,
        height: 1.2,
        fontWeight: FontWeight.w500,
        color: ink,
      ),
      headlineSmall: TextStyle(
        fontFamily: display,
        fontSize: 18,
        height: 1.25,
        fontWeight: FontWeight.w500,
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
