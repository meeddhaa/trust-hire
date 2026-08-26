import 'package:flutter/material.dart';

/// TrustHire's "Ember" palette — replaces "Northern Ledger" (indigo/
/// graphite; kept in git history) per explicit user-supplied UI reference:
/// near-black dark surfaces, warm off-white text, and a single vivid
/// orange accent, matching a dark photo-card job-app reference exactly by
/// request (superseding the earlier "avoid cliché colors, blend layout
/// ideas" direction — this is a literal "build the whole app around this"
/// instruction). See docs/ARCHITECTURE.md "Decision: Ember palette".
///
/// The one deliberate deviation from the reference: [caution] (the
/// scam-risk "Caution" trust badge) is kept a muted, dark gold — visibly
/// less saturated than [accent] — rather than also being orange. The
/// reference's orange is a decorative brand color; ours would collide
/// with an existing safety signal if reused verbatim (a verdict must
/// never read as "this is a button", see RiskColors' doc comment).
abstract final class AppColors {
  // --- Light ---
  static const Color ledgerBg = Color(0xFFF2F1EF);
  static const Color ledgerSurface = Color(0xFFFFFFFF);
  static const Color ledgerInk = Color(0xFF16171B);
  static const Color ledgerInkMuted = Color(0xFF6B6C75);
  static const Color ledgerOutline = Color(0xFFE3E3E1);

  // --- Dark (the reference's primary look — near-black, not graphite-blue) ---
  static const Color graphiteBg = Color(0xFF121214);
  static const Color graphiteSurface = Color(0xFF1C1D21);
  static const Color graphiteText = Color(0xFFF2F1ED);
  static const Color graphiteTextMuted = Color(0xFF9C9DA6);
  static const Color graphiteOutline = Color(0xFF2B2C32);

  // --- Brand accent (CTAs, score arc, links, active states) ---
  static const Color accent = Color(0xFFFF5A1F);
  static const Color accentStrong = Color(0xFFE14A15);
  static const Color accentOnAccent = Color(0xFFFFFFFF); // text/icons on accent

  // --- Risk / verdict scale — used ONLY for trust badges & match verdicts.
  // `caution` is deliberately a muted dark gold, not orange — see the
  // class doc comment for why that one color can't just copy the
  // reference.
  static const Color verifiedLeaning = Color(0xFF3E5C54);
  static const Color verifiedLeaningBg = Color(0xFFE1E9E5);
  static const Color caution = Color(0xFFA07A1E);
  static const Color cautionBg = Color(0xFFF1E6C8);
  static const Color highRisk = Color(0xFF9B3A2C);
  static const Color highRiskBg = Color(0xFFF1DAD5);

  // Dark-mode variants of the risk scale (lifted lightness so they read on
  // dark surfaces without losing the muted, non-neon character, and
  // staying visibly less saturated than the accent orange).
  static const Color verifiedLeaningDark = Color(0xFF7FA396);
  static const Color cautionDark = Color(0xFFD3A94E);
  static const Color highRiskDark = Color(0xFFD07362);
}
