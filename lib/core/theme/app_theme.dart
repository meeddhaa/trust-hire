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
      onSecondary: AppColors.paperSurface,
      error: AppColors.highRisk,
      onError: AppColors.paperSurface,
      surface: AppColors.paperSurface,
      onSurface: AppColors.paperInk,
      surfaceContainerHighest: AppColors.paperBg,
      onSurfaceVariant: AppColors.paperInkMuted,
      outline: AppColors.paperOutline,
    );

    return _build(
      scheme: scheme,
      scaffoldBg: AppColors.paperBg,
      ink: AppColors.paperInk,
      inkMuted: AppColors.paperInkMuted,
      outline: AppColors.paperOutline,
      riskColors: RiskColors.light,
    );
  }

  static ThemeData dark() {
    const scheme = ColorScheme(
      brightness: Brightness.dark,
      primary: AppColors.accent,
      onPrimary: AppColors.accentOnAccent,
      secondary: AppColors.verifiedLeaningDark,
      onSecondary: AppColors.inkBg,
      error: AppColors.highRiskDark,
      onError: AppColors.inkBg,
      surface: AppColors.inkSurface,
      onSurface: AppColors.inkText,
      surfaceContainerHighest: AppColors.inkBg,
      onSurfaceVariant: AppColors.inkTextMuted,
      outline: AppColors.inkOutline,
    );

    return _build(
      scheme: scheme,
      scaffoldBg: AppColors.inkBg,
      ink: AppColors.inkText,
      inkMuted: AppColors.inkTextMuted,
      outline: AppColors.inkOutline,
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
      cardTheme: CardThemeData(
        color: scheme.surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: outline, width: 1),
        ),
      ),

      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: scheme.primary,
          foregroundColor: scheme.onPrimary,
          disabledBackgroundColor: outline,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          textStyle: textTheme.labelLarge,
          elevation: 0,
        ),
      ),

      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: ink,
          side: BorderSide(color: outline, width: 1.2),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
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
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: outline),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: outline),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: scheme.primary, width: 1.5),
        ),
        hintStyle: textTheme.bodyMedium?.copyWith(color: inkMuted),
      ),

      dividerTheme: DividerThemeData(color: outline, thickness: 1, space: 1),

      chipTheme: ChipThemeData(
        backgroundColor: scheme.surfaceContainerHighest,
        side: BorderSide(color: outline),
        labelStyle: textTheme.labelMedium,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }
}
