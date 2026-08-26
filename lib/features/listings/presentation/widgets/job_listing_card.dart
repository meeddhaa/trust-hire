import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../../core/providers/repository_providers.dart';
import '../../../../core/providers/session_providers.dart';
import '../../../../core/theme/app_motion.dart';
import '../../../../core/theme/risk_colors.dart';
import '../../../../data/models/job_listing.dart';
import '../../../../data/models/scam_assessment.dart';
import '../../../../data/services/scam_rule_engine.dart';
import '../../../../shared/widgets/trust_badge_chip.dart';
import '../../../saved_jobs/providers/saved_jobs_providers.dart';

/// A listing in the feed. Shows only the trust badge, computed instantly
/// and client-side by [ScamRuleEngine] — not a match score, which needs a
/// (cached) Gemini call per `MatchRepository`. Firing that per card on
/// every feed scroll is exactly the API-quota-burning the brief warns
/// against for scam scoring, and the same reasoning extends to match
/// scoring: it only gets computed once a listing is actually opened (see
/// `listing_detail`), where the real number becomes the screen's
/// centerpiece.
class JobListingCard extends ConsumerWidget {
  const JobListingCard({
    super.key,
    required this.listing,
    required this.onTap,
    this.staggerIndex = 0,
  });

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

  static Color _borderColorFor(TrustBadge badge, RiskColors risk) =>
      switch (badge) {
        TrustBadge.verifiedLeaning => risk.verifiedLeaning,
        TrustBadge.caution => risk.caution,
        TrustBadge.highRisk => risk.highRisk,
      };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = Theme.of(context).textTheme;
    final risk = Theme.of(context).extension<RiskColors>()!;
    final assessment = ScamRuleEngine.assess(listing);
    final borderColor = _borderColorFor(assessment.trustBadge, risk);
    final salaryLine = _salaryLine;
    final isSaved =
        ref.watch(isJobSavedProvider(listing.id)).valueOrNull ?? false;
    final uid = ref.read(currentUidProvider);

    return Card(
          // A colored left rail, not a full-card tint — lets the trust badge's
          // signal be scanned at a glance down the feed without the color
          // fighting the card's actual content, and without a "this whole
          // listing is a solid color" look reading as more alarming/exciting
          // than the badge text alone.
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide(
              color: borderColor.withValues(alpha: 0.55),
              width: 1,
            ),
          ),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(20),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 16, 16, 16),
              // IntrinsicHeight, not just Row(crossAxisAlignment: stretch) —
              // this Row sits in a ListView item, where incoming height is
              // unbounded (it sizes to content). `stretch` alone needs a
              // bounded height to stretch to and threw "BoxConstraints forces
              // an infinite height" without it — a real crash caught live,
              // not a hypothetical: it blanked the entire feed with no
              // exception surfaced past logcat (Flutter's error boundary
              // still painted the rest of the frame; there was just nothing
              // valid left to paint for every card). IntrinsicHeight measures
              // the tallest child first, giving the Row a real height to
              // stretch the colored rail against.
              child: IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Container(
                      width: 4,
                      margin: const EdgeInsets.only(right: 12),
                      decoration: BoxDecoration(
                        color: borderColor,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    Expanded(
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
                                    Text(
                                      listing.company,
                                      style: text.bodyMedium,
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              TrustBadgeChip(
                                badge: assessment.trustBadge,
                                compact: true,
                              ),
                              // Saved state gets its own color, not just a
                              // filled-vs-outline icon swap — accent when saved,
                              // muted when not, so the bookmark itself reads as
                              // "on/off" at a glance.
                              IconButton(
                                icon: Icon(
                                  isSaved
                                      ? Icons.bookmark
                                      : Icons.bookmark_border,
                                ),
                                color: isSaved
                                    ? Theme.of(context).colorScheme.primary
                                    : Theme.of(
                                        context,
                                      ).colorScheme.onSurfaceVariant,
                                tooltip: isSaved
                                    ? 'Remove from saved'
                                    : 'Save for later',
                                visualDensity: VisualDensity.compact,
                                onPressed: uid == null
                                    ? null
                                    : () {
                                        final repo = ref.read(
                                          savedJobRepositoryProvider,
                                        );
                                        if (isSaved) {
                                          repo.unsave(
                                            uid: uid,
                                            listingId: listing.id,
                                          );
                                        } else {
                                          repo.save(
                                            uid: uid,
                                            listingId: listing.id,
                                          );
                                        }
                                      },
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Wrap(
                            spacing: 14,
                            runSpacing: 6,
                            children: [
                              _MetaChip(
                                icon: Icons.place_outlined,
                                label: listing.location,
                              ),
                              if (listing.isRemote)
                                const _MetaChip(
                                  icon: Icons.wifi,
                                  label: 'Remote',
                                ),
                              if (salaryLine != null)
                                _MetaChip(
                                  icon: Icons.payments_outlined,
                                  label: salaryLine,
                                ),
                            ],
                          ),
                          if (listing.requiredSkills.isNotEmpty) ...[
                            const SizedBox(height: 12),
                            Wrap(
                              spacing: 6,
                              runSpacing: 6,
                              children: [
                                for (final skill in listing.requiredSkills.take(
                                  5,
                                ))
                                  Chip(
                                    label: Text(skill),
                                    visualDensity: VisualDensity.compact,
                                    materialTapTargetSize:
                                        MaterialTapTargetSize.shrinkWrap,
                                  ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        )
        .animate(delay: AppMotion.feedStagger * staggerIndex)
        .fadeIn(duration: AppMotion.standard, curve: AppMotion.settle)
        .slideY(
          begin: 0.08,
          end: 0,
          duration: AppMotion.standard,
          curve: AppMotion.settle,
        );
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
