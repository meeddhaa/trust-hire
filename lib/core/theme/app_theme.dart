import 'package:flutter/material.dart';
import 'app_colors.dart';
import 'app_typography.dart';
import 'risk_colors.dart';

/// Builds TrustHire's light/dark `ThemeData`.
///
/// Deliberately not `ColorScheme.fromSeed()` — every role is assigned an
/// explicit color from [AppColors] so the palette stays exactly what was
/// designed, not a Material tonal-palette derivation from one seed hue.
abstract final class AppTheme {
  static ThemeData light() {
    const scheme = ColorScheme(
      brightness: Brightness.light,
      primary: AppColors.accent,
      onPrimary: AppColors.accentOnAccent,
      secondary: AppColors.verifiedLeaning,
      onSecondary: AppColors.ledgerSurface,
      error: AppColors.highRisk,
      onError: AppColors.ledgerSurface,
      surface: AppColors.ledgerSurface,
      onSurface: AppColors.ledgerInk,
      surfaceContainerHighest: AppColors.ledgerBg,
      onSurfaceVariant: AppColors.ledgerInkMuted,
      outline: AppColors.ledgerOutline,
    );

    return _build(
      scheme: scheme,
      scaffoldBg: AppColors.ledgerBg,
      ink: AppColors.ledgerInk,
      inkMuted: AppColors.ledgerInkMuted,
      outline: AppColors.ledgerOutline,
      riskColors: RiskColors.light,
    );
  }

  static ThemeData dark() {
    const scheme = ColorScheme(
      brightness: Brightness.dark,
      primary: AppColors.accent,
      onPrimary: AppColors.accentOnAccent,
      secondary: AppColors.verifiedLeaningDark,
      onSecondary: AppColors.graphiteBg,
      error: AppColors.highRiskDark,
      onError: AppColors.graphiteBg,
      surface: AppColors.graphiteSurface,
      onSurface: AppColors.graphiteText,
      surfaceContainerHighest: AppColors.graphiteBg,
      onSurfaceVariant: AppColors.graphiteTextMuted,
      outline: AppColors.graphiteOutline,
    );

    return _build(
      scheme: scheme,
      scaffoldBg: AppColors.graphiteBg,
      ink: AppColors.graphiteText,
      inkMuted: AppColors.graphiteTextMuted,
      outline: AppColors.graphiteOutline,
      riskColors: RiskColors.dark,
    );
  }

  static ThemeData _build({
    required ColorScheme scheme,
    required Color scaffoldBg,
    required Color ink,
    required Color inkMuted,
    required Color outline,
    required RiskColors riskColors,
  }) {
    final textTheme = AppTypography.textTheme(ink, inkMuted);

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: scaffoldBg,
      fontFamily: AppTypography.ui,
      textTheme: textTheme,
      extensions: [riskColors],

      appBarTheme: AppBarTheme(
        backgroundColor: scaffoldBg,
        foregroundColor: ink,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: textTheme.headlineSmall,
      ),

      // Flat, bordered cards — not the stock elevated-shadow list card.
      // Radius bumped from 20→24 as part of the bolder, more confident
      // card language borrowed from the reference redesign (both the
      // light-dashboard and dark-photo-card directions use noticeably
      // rounder cards than "Editorial Trust"'s original, more restrained
      // 20px).
      cardTheme: CardThemeData(
        color: scheme.surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: BorderSide(color: outline, width: 1),
        ),
      ),

      // Pill-shaped, not just rounded-rect — matches the reference's bold
      // "Apply Job" / "Apply for this Job" CTA language. Still flat
      // (elevation 0), same principle as the cards: color and shape carry
      // the weight, not a drop shadow.
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: scheme.primary,
          foregroundColor: scheme.onPrimary,
          disabledBackgroundColor: outline,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          shape: const StadiumBorder(),
          textStyle: textTheme.labelLarge,
          elevation: 0,
        ),
      ),

      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: ink,
          side: BorderSide(color: outline, width: 1.2),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          shape: const StadiumBorder(),
          textStyle: textTheme.labelLarge,
        ),
      ),

      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: scheme.primary,
          textStyle: textTheme.labelLarge,
        ),
      ),

      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: scheme.surface,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide: BorderSide(color: outline),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide: BorderSide(color: outline),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide: BorderSide(color: scheme.primary, width: 1.5),
        ),
        hintStyle: textTheme.bodyMedium?.copyWith(color: inkMuted),
      ),

      dividerTheme: DividerThemeData(color: outline, thickness: 1, space: 1),

      // Pill chips (StadiumBorder), not the original 10px rounded-rect —
      // matches the reference's filter-chip and meta-tag language.
      chipTheme: ChipThemeData(
        backgroundColor: scheme.surfaceContainerHighest,
        side: BorderSide(color: outline),
        labelStyle: textTheme.labelMedium,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        shape: const StadiumBorder(),
      ),

      // Explicit, not left to Material defaults: SegmentedButton's default
      // selected-state styling pulls from `colorScheme.secondary`, which
      // we deliberately set to the risk-verdict teal (see RiskColors doc
      // comment) — left unstyled, a plain "Light/Dark/System" toggle would
      // render its selected segment in the same teal a "Verified-leaning"
      // badge uses, diluting that color's meaning as a risk signal rather
      // than a generic UI affordance. Any other selection-style widget
      // added later (FilterChip, ChoiceChip, ...) needs the same explicit
      // treatment for the same reason.
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: SegmentedButton.styleFrom(
          selectedBackgroundColor: scheme.primary,
          selectedForegroundColor: scheme.onPrimary,
          foregroundColor: ink,
          side: BorderSide(color: outline),
        ),
      ),

      // Same reasoning as segmentedButtonTheme above: NavigationBar's
      // default selected-tab indicator is `colorScheme.secondaryContainer`
      // — without this, the bottom nav's active tab would render in the
      // risk-verdict teal too.
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: scaffoldBg,
        indicatorColor: scheme.primary.withValues(alpha: 0.16),
        indicatorShape: const StadiumBorder(),
        iconTheme: WidgetStateProperty.resolveWith(
          (states) => IconThemeData(
            color: states.contains(WidgetState.selected) ? scheme.primary : inkMuted,
          ),
        ),
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => textTheme.labelSmall?.copyWith(
            color: states.contains(WidgetState.selected) ? scheme.primary : inkMuted,
          ),
        ),
      ),
    );
  }
}
