import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../core/theme/app_motion.dart';
import '../../core/theme/risk_colors.dart';
import '../../data/models/scam_assessment.dart';

/// The trust-badge visual centerpiece: a hold-then-stamp reveal, per the
/// confirmed motion language — not a static label. Promoted from
/// `theme_preview_page.dart` once screens started consuming it.
class TrustBadgeChip extends StatelessWidget {
  const TrustBadgeChip({super.key, required this.badge, this.delay = Duration.zero, this.compact = false});

  final TrustBadge badge;
  final Duration delay;

  /// Smaller padding/type for use inline on a feed card, vs. the full
  /// size used as the listing-detail centerpiece.
  final bool compact;

  static String labelFor(TrustBadge badge) => switch (badge) {
        TrustBadge.verifiedLeaning => 'Verified-leaning',
        TrustBadge.caution => 'Caution',
        TrustBadge.highRisk => 'High Risk',
      };

  static IconData iconFor(TrustBadge badge) => switch (badge) {
        TrustBadge.verifiedLeaning => Icons.verified_outlined,
        TrustBadge.caution => Icons.error_outline,
        TrustBadge.highRisk => Icons.warning_amber_rounded,
      };

  @override
  Widget build(BuildContext context) {
    final risk = Theme.of(context).extension<RiskColors>()!;
    final (fg, bg) = switch (badge) {
      TrustBadge.verifiedLeaning => (risk.verifiedLeaning, risk.verifiedLeaningBg),
      TrustBadge.caution => (risk.caution, risk.cautionBg),
      TrustBadge.highRisk => (risk.highRisk, risk.highRiskBg),
    };
    final labelStyle = compact
        ? Theme.of(context).textTheme.labelMedium?.copyWith(color: fg)
        : Theme.of(context).textTheme.labelLarge?.copyWith(color: fg);

    return Container(
      padding: EdgeInsets.symmetric(horizontal: compact ? 10 : 14, vertical: compact ? 6 : 10),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(compact ? 10 : 12)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(iconFor(badge), size: compact ? 14 : 18, color: fg),
          SizedBox(width: compact ? 4 : 6),
          Text(labelFor(badge), style: labelStyle),
        ],
      ),
    )
        .animate(delay: AppMotion.badgeHold + delay)
        .scaleXY(begin: 0.7, end: 1.0, duration: AppMotion.badgeReveal, curve: AppMotion.stamp)
        .fadeIn(duration: AppMotion.fast);
  }
}
