import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/app_motion.dart';
import '../../../../data/models/job_listing.dart';
import '../../../../data/services/scam_rule_engine.dart';
import '../../../../shared/widgets/trust_badge_chip.dart';

/// A listing in the feed. Shows only the trust badge, computed instantly
/// and client-side by [ScamRuleEngine] — not a match score, which needs a
/// (cached) Gemini call per `MatchRepository`. Firing that per card on
/// every feed scroll is exactly the API-quota-burning the brief warns
/// against for scam scoring, and the same reasoning extends to match
/// scoring: it only gets computed once a listing is actually opened (see
/// `listing_detail`), where the real number becomes the screen's
/// centerpiece.
class JobListingCard extends StatelessWidget {
  const JobListingCard({super.key, required this.listing, required this.onTap, this.staggerIndex = 0});

  final JobListing listing;
  final VoidCallback onTap;

  /// Position in the feed, for the staggered entrance delay.
  final int staggerIndex;

  static final _salaryFormat = NumberFormat.decimalPattern();

  String? get _salaryLine {
    final min = listing.salaryMin;
    final max = listing.salaryMax;
    if (min == null && max == null) return null;
    final currency = listing.salaryCurrency;
    if (min != null && max != null) {
      return '${_salaryFormat.format(min)}–${_salaryFormat.format(max)} $currency/mo';
    }
    return '${_salaryFormat.format(min ?? max)} $currency/mo';
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final assessment = ScamRuleEngine.assess(listing);
    final salaryLine = _salaryLine;

    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(listing.title, style: text.titleLarge),
                        const SizedBox(height: 2),
                        Text(listing.company, style: text.bodyMedium),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  TrustBadgeChip(badge: assessment.trustBadge, compact: true),
                ],
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 14,
                runSpacing: 6,
                children: [
                  _MetaChip(icon: Icons.place_outlined, label: listing.location),
                  if (listing.isRemote) const _MetaChip(icon: Icons.wifi, label: 'Remote'),
                  if (salaryLine != null) _MetaChip(icon: Icons.payments_outlined, label: salaryLine),
                ],
              ),
              if (listing.requiredSkills.isNotEmpty) ...[
                const SizedBox(height: 12),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final skill in listing.requiredSkills.take(5))
                      Chip(
                        label: Text(skill),
                        visualDensity: VisualDensity.compact,
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    )
        .animate(delay: AppMotion.feedStagger * staggerIndex)
        .fadeIn(duration: AppMotion.standard, curve: AppMotion.settle)
        .slideY(begin: 0.08, end: 0, duration: AppMotion.standard, curve: AppMotion.settle);
  }
}

class _MetaChip extends StatelessWidget {
  const _MetaChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 15, color: muted),
        const SizedBox(width: 4),
        Text(label, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }
}
