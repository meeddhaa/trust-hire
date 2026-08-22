import 'package:flutter/material.dart';

/// TrustHire's "Editorial Trust" palette.
///
/// Deliberately not a Material `ColorScheme.fromSeed` derivation and not a
/// fintech blue/green: a warm paper/ink base with a single confident amber
/// accent, plus a *separate* three-step risk scale reserved for scam/match
/// verdicts so those badges read as data, not brand decoration.
abstract final class AppColors {
  // --- Light ("paper") ---
  static const Color paperBg = Color(0xFFF7F3EC);
  static const Color paperSurface = Color(0xFFFFFCF7);
  static const Color paperInk = Color(0xFF1B1812);
  static const Color paperInkMuted = Color(0xFF6B6255);
  static const Color paperOutline = Color(0xFFE3DACB);

  // --- Dark ("ink") ---
  static const Color inkBg = Color(0xFF15130F);
  static const Color inkSurface = Color(0xFF1E1B15);
  static const Color inkText = Color(0xFFF4EFE6);
  static const Color inkTextMuted = Color(0xFFB4AA98);
  static const Color inkOutline = Color(0xFF3A362C);

  // --- Brand accent (CTAs, score arc, links, active states) ---
  static const Color accent = Color(0xFFB5722A);
  static const Color accentStrong = Color(0xFF8F5A20);
  static const Color accentOnAccent = Color(0xFFFFFCF7); // text/icons on accent

  // --- Risk / verdict scale — used ONLY for trust badges & match verdicts ---
  static const Color verifiedLeaning = Color(0xFF3E5C54);
  static const Color verifiedLeaningBg = Color(0xFFE1E9E5);
  static const Color caution = Color(0xFFC9922E);
  static const Color cautionBg = Color(0xFFF5E7CC);
  static const Color highRisk = Color(0xFF9B3A2C);
  static const Color highRiskBg = Color(0xFFF1DAD5);

  // Dark-mode variants of the risk scale (lifted lightness so they read on
  // dark surfaces without losing the muted, non-neon character).
  static const Color verifiedLeaningDark = Color(0xFF7FA396);
  static const Color cautionDark = Color(0xFFE0AC57);
  static const Color highRiskDark = Color(0xFFD07362);
}
