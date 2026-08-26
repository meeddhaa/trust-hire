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

/// A listing in the feed, restyled per the user-supplied reference: a
/// colored "photo" panel (tag + bookmark only) up top, then a distinct
/// light strip below it carrying title + salary, then a secondary meta
/// row this app actually needs (trust badge, skills) that the reference
/// has no equivalent for.
///
/// The reference's panel is a real photo of the workspace; ours is a flat
/// gradient instead (see [CompanyAvatar.colorFor], the same deterministic
/// per-company color used for the small round avatar elsewhere) — JSearch
/// gives no listing imagery, and placing a stock/generic photo next to a
/// real employer's name would misrepresent them.
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
      return '${_salaryFormat.format(min)}–${_salaryFormat.format(max)}\n$currency';
    }
    return '${_salaryFormat.format(min ?? max)}\n$currency';
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
    final scheme = Theme.of(context).colorScheme;
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
            // The colored "photo" panel — tag + bookmark only, no text
            // overlay (the reference keeps its photo clean and puts
            // title/salary in the light strip below instead).
            AspectRatio(
              aspectRatio: 16 / 9,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [panelColor, Color.lerp(panelColor, Colors.black, 0.35)!],
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _PanelTag(
                        label: listing.isRemote ? 'Remote' : 'On-site',
                        icon: listing.isRemote ? Icons.wifi : Icons.apartment_outlined,
                        accent: listing.isRemote,
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
                ),
              ),
            ),

            // The light "price strip" — title + location on the left,
            // salary bold on the right, matching the reference's card
            // exactly (its "Web Designer / New York, USA" + "$10K–$12K /
            // month" row).
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          listing.title,
                          style: text.titleMedium,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(listing.location, style: text.bodySmall),
                      ],
                    ),
                  ),
                  if (salaryLine != null) ...[
                    const SizedBox(width: 10),
                    Text(
                      salaryLine,
                      textAlign: TextAlign.right,
                      style: text.labelLarge?.copyWith(color: scheme.primary, fontWeight: FontWeight.w800),
                    ),
                  ],
                ],
              ),
            ),

            const Divider(height: 1),

            // Secondary meta row: company identity, trust badge (this
            // app's actual reason to exist, and absent from the reference
            // entirely), freshness, and required skills.
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      CompanyAvatar(company: listing.company, size: 26),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(listing.company, style: text.labelLarge, overflow: TextOverflow.ellipsis),
                      ),
                      const SizedBox(width: 8),
                      TrustBadgeChip(badge: assessment.trustBadge, compact: true),
                    ],
                  ),
                  const SizedBox(height: 8),
                  _MetaChip(icon: Icons.schedule_outlined, label: _postedAgo),
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
  const _PanelTag({required this.label, required this.icon, required this.accent});

  final String label;
  final IconData icon;

  /// True for the tag that should get the vivid accent treatment (the
  /// reference's "Part Remote" tag is a warm accent color; its other tags
  /// are a plain dark/translucent pill) — here, "Remote" gets the accent,
  /// "On-site" gets the dark translucent treatment.
  final bool accent;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final bg = accent ? scheme.primary : Colors.black.withValues(alpha: 0.55);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: Colors.white),
          const SizedBox(width: 4),
          Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(color: Colors.white, fontWeight: FontWeight.w700),
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
        color: Colors.white.withValues(alpha: 0.92),
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
