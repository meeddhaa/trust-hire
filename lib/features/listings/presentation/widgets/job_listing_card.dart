import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../../core/providers/repository_providers.dart';
import '../../../../core/providers/session_providers.dart';
import '../../../../core/theme/app_motion.dart';
import '../../../../data/models/job_listing.dart';
import '../../../../data/services/scam_rule_engine.dart';
import '../../../../shared/widgets/company_avatar.dart';
import '../../../../shared/widgets/trust_badge_chip.dart';
import '../../../saved_jobs/providers/saved_jobs_providers.dart';

/// A listing in the feed, restyled as a "hero panel" card per the
/// user-supplied dark photo-card reference: a colored block up top with
/// the badge tag / bookmark / title / salary overlaid, then a meta row
/// below.
///
/// The reference's panel is a real photo of the workspace; ours is a flat
/// color instead (see [CompanyAvatar.colorFor], the same deterministic
/// per-company color used for the small round avatar elsewhere) — JSearch
/// gives no listing imagery, and placing a stock/generic photo next to a
/// real employer's name would misrepresent them. The trust badge (this
/// app's actual reason to exist, and absent from the reference entirely)
/// stays in the meta row below the panel rather than being dropped for
/// fidelity to the reference.
class JobListingCard extends ConsumerWidget {
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
      return '${_salaryFormat.format(min)}–${_salaryFormat.format(max)} $currency';
    }
    return '${_salaryFormat.format(min ?? max)} $currency';
  }

  /// A real, honest "freshness" signal (unlike the reference's fabricated
  /// applicant counts, which nothing in this app's data actually
  /// supports) — how long ago the listing was posted, from real seeded
  /// data.
  String get _postedAgo {
    final days = DateTime.now().difference(listing.postedAt).inDays;
    if (days <= 0) return 'Today';
    if (days == 1) return 'Yesterday';
    if (days < 7) return '${days}d ago';
    final weeks = days ~/ 7;
    return '${weeks}w ago';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = Theme.of(context).textTheme;
    final assessment = ScamRuleEngine.assess(listing);
    final panelColor = CompanyAvatar.colorFor(listing.company);
    final salaryLine = _salaryLine;
    final isSaved = ref.watch(isJobSavedProvider(listing.id)).valueOrNull ?? false;
    final uid = ref.read(currentUidProvider);

    return Card(
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // The colored "hero" panel — badge tag + bookmark up top,
            // title + salary overlaid at the bottom on a gradient dark
            // enough for white text to stay legible over any panel color.
            AspectRatio(
              aspectRatio: 16 / 9,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [panelColor.withValues(alpha: 0.85), Color.lerp(panelColor, Colors.black, 0.55)!],
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          _PanelTag(
                            label: listing.isRemote ? 'Remote' : 'On-site',
                            icon: listing.isRemote ? Icons.wifi : Icons.apartment_outlined,
                          ),
                          const Spacer(),
                          _PanelIconButton(
                            icon: isSaved ? Icons.bookmark : Icons.bookmark_border,
                            active: isSaved,
                            tooltip: isSaved ? 'Remove from saved' : 'Save for later',
                            onTap: uid == null
                                ? null
                                : () {
                                    final repo = ref.read(savedJobRepositoryProvider);
                                    if (isSaved) {
                                      repo.unsave(uid: uid, listingId: listing.id);
                                    } else {
                                      repo.save(uid: uid, listingId: listing.id);
                                    }
                                  },
                          ),
                        ],
                      ),
                      const Spacer(),
                      Text(
                        listing.title,
                        style: text.titleLarge?.copyWith(color: Colors.white),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (salaryLine != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          salaryLine,
                          style: text.titleMedium?.copyWith(color: Colors.white, fontWeight: FontWeight.w800),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),

            // Meta row: company identity, trust badge (this app's actual
            // reason to exist — kept even though the reference has no
            // equivalent), location, and freshness.
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      CompanyAvatar(company: listing.company, size: 28),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(listing.company, style: text.titleSmall, overflow: TextOverflow.ellipsis),
                      ),
                      const SizedBox(width: 8),
                      TrustBadgeChip(badge: assessment.trustBadge, compact: true),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 14,
                    runSpacing: 6,
                    children: [
                      _MetaChip(icon: Icons.place_outlined, label: listing.location),
                      _MetaChip(icon: Icons.schedule_outlined, label: _postedAgo),
                    ],
                  ),
                  if (listing.requiredSkills.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        for (final skill in listing.requiredSkills.take(4))
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
          ],
        ),
      ),
    )
        .animate(delay: AppMotion.feedStagger * staggerIndex)
        .fadeIn(duration: AppMotion.standard, curve: AppMotion.settle)
        .slideY(begin: 0.08, end: 0, duration: AppMotion.standard, curve: AppMotion.settle);
  }
}

class _PanelTag extends StatelessWidget {
  const _PanelTag({required this.label, required this.icon});

  final String label;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: Colors.black87),
          const SizedBox(width: 4),
          Text(
            label,
            style: Theme.of(context)
                .textTheme
                .labelSmall
                ?.copyWith(color: Colors.black87, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}

class _PanelIconButton extends StatelessWidget {
  const _PanelIconButton({required this.icon, required this.active, required this.tooltip, required this.onTap});

  final IconData icon;
  final bool active;
  final String tooltip;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.white.withValues(alpha: 0.9),
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(7),
            child: Icon(icon, size: 17, color: active ? accent : Colors.black87),
          ),
        ),
      ),
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
