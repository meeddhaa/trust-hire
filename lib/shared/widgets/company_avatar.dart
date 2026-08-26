import 'package:flutter/material.dart';
import '../../core/theme/app_typography.dart';

/// A colored circular "logo" badge showing a company's first letter —
/// stands in for a real company logo, which the app has no legitimate
/// source for (JSearch gives no logo asset, and rendering a guessed/stock
/// image next to a real employer's name would misrepresent them). Color
/// is deterministic per company name (a stable hash into a fixed palette),
/// not random, so the same company always reads the same color across the
/// feed, applications, and saved lists.
///
/// The palette is deliberately disjoint from [RiskColors]' verdict scale
/// (green/amber/red) and from the brand accent — this badge is a visual
/// identity marker, never a signal, so it must not be mistakable for a
/// trust badge or a call-to-action.
class CompanyAvatar extends StatelessWidget {
  const CompanyAvatar({super.key, required this.company, this.size = 44});

  final String company;
  final double size;

  static const _palette = [
    Color(0xFF3B6E91), // slate blue
    Color(0xFF7A5CC7), // violet
    Color(0xFFB5568A), // mauve
    Color(0xFF8A6D3B), // bronze
    Color(0xFF4E7A6B), // muted teal-green (kept dark/desaturated, far from riskColors.verifiedLeaning)
    Color(0xFF6B6F8C), // slate
    Color(0xFFA6613F), // terracotta
    Color(0xFF54739E), // steel blue
  ];

  /// Exposed statically so other widgets that want the "same identity
  /// color" as a company's avatar (e.g. the feed card's hero panel
  /// background) can compute it without instantiating a whole
  /// [CompanyAvatar].
  static Color colorFor(String name) {
    final normalized = name.trim().toLowerCase();
    if (normalized.isEmpty) return _palette.first;
    final hash = normalized.codeUnits.fold<int>(0, (acc, unit) => (acc * 31 + unit) & 0x7fffffff);
    return _palette[hash % _palette.length];
  }

  @override
  Widget build(BuildContext context) {
    final initial = company.trim().isEmpty ? '?' : company.trim()[0].toUpperCase();
    return CircleAvatar(
      radius: size / 2,
      backgroundColor: colorFor(company),
      child: Text(
        initial,
        style: TextStyle(
          fontFamily: AppTypography.display,
          fontSize: size * 0.42,
          fontWeight: FontWeight.w600,
          color: Colors.white,
        ),
      ),
    );
  }
}
