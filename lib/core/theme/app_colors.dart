import 'package:flutter/material.dart';

/// TrustHire's "Northern Ledger" palette — replaces the original
/// "Editorial Trust" warm paper/ink direction (kept in git history; see
/// docs/ARCHITECTURE.md "Decision: Northern Ledger palette" for why).
///
/// Cool slate/graphite base with a single deep indigo-violet accent.
/// Deliberately not blue or green — the brief calls out "trust and
/// clarity without being a cliché blue/green fintech palette," and violet
/// reads as considered/precise without landing on either cliché. Not a
/// Material `ColorScheme.fromSeed` derivation — every role is an explicit
/// value, same principle as before.
abstract final class AppColors {
  // --- Light ("ledger") ---
  static const Color ledgerBg = Color(0xFFF4F5F8);
  static const Color ledgerSurface = Color(0xFFFFFFFF);
  static const Color ledgerInk = Color(0xFF1A1B22);
  static const Color ledgerInkMuted = Color(0xFF5B5F6E);
  static const Color ledgerOutline = Color(0xFFDDE0E7);

  // --- Dark ("graphite") ---
  static const Color graphiteBg = Color(0xFF1C1E26);
  static const Color graphiteSurface = Color(0xFF24262F);
  static const Color graphiteText = Color(0xFFE8E9EE);
  static const Color graphiteTextMuted = Color(0xFF9497A6);
  static const Color graphiteOutline = Color(0xFF343745);

  // --- Brand accent (CTAs, score arc, links, active states) ---
  static const Color accent = Color(0xFF5B5FEF);
  static const Color accentStrong = Color(0xFF4548C4);
  static const Color accentOnAccent = Color(0xFFFFFFFF); // text/icons on accent

  // --- Risk / verdict scale — used ONLY for trust badges & match verdicts.
  // Deliberately kept a separate muted earth-tone family from the cool
  // indigo brand accent, same principle as before: a verdict should read
  // as data, not brand decoration, so it must never be confusable with a
  // "this is a link/button" affordance.
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
