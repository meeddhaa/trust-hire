import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/providers/session_providers.dart';
import '../../../core/theme/risk_colors.dart';
import '../../../data/models/job_listing.dart';
import '../../../data/models/match_result.dart';
import '../../../data/models/scam_assessment.dart';
import '../../../shared/widgets/expandable_section.dart';
import '../../../shared/widgets/match_score_dial.dart';
import '../../../shared/widgets/trust_badge_chip.dart';
import '../providers/listing_detail_providers.dart';
import 'source_webview_screen.dart';

/// The match + trust badge centerpiece screen. Free tier sees the match
/// percent and trust badge (both real, Gemini-backed/rule-backed
/// numbers); paid tier additionally sees the gap breakdown, upskilling
/// roadmap, and the LLM's scam-risk reasoning paragraph — see
/// `docs/ARCHITECTURE.md` → "Data flow: match + scam assessment" for why
/// the gating happens here in the UI layer rather than in what gets
/// fetched or cached.
class ListingDetailScreen extends ConsumerWidget {
  const ListingDetailScreen({super.key, required this.listingId});

  final String listingId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final listingAsync = ref.watch(listingByIdProvider(listingId));

    return Scaffold(
      appBar: AppBar(title: const Text('Listing')),
      body: listingAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(error.toString(), textAlign: TextAlign.center),
        )),
        data: (listing) {
          if (listing == null) {
            return const Center(child: Text("This listing isn't available anymore."));
          }
          return _ListingDetailBody(listing: listing);
        },
      ),
    );
  }
}

class _ListingDetailBody extends ConsumerWidget {
  const _ListingDetailBody({required this.listing});

  final JobListing listing;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = Theme.of(context).textTheme;
    final subscription = ref.watch(currentSubscriptionProvider).valueOrNull;
    final isPaid = subscription?.isPaid ?? false;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(listing.title, style: text.headlineMedium),
          const SizedBox(height: 4),
          Text(listing.company, style: text.bodyLarge),
          const SizedBox(height: 4),
          Text(
            '${listing.location}${listing.isRemote ? ' · Remote' : ''}',
            style: text.bodyMedium,
          ),
          const SizedBox(height: 24),

          _MatchSection(listing: listing, isPaid: isPaid),
          const SizedBox(height: 20),
          _TrustSection(listing: listing, isPaid: isPaid),
          const SizedBox(height: 20),

          if (!isPaid)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    const Icon(Icons.lock_outline_rounded),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Unlock the full gap breakdown, upskilling roadmap, and scam-risk reasoning.',
                        style: text.bodyMedium,
                      ),
                    ),
                    TextButton(
                      onPressed: () => context.push('/paywall'),
                      child: const Text('Upgrade'),
                    ),
                  ],
                ),
              ),
            ),

          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => SourceWebviewScreen(url: listing.sourceUrl, title: listing.company),
              ),
            ),
            icon: const Icon(Icons.open_in_new_rounded),
            label: const Text('View original posting'),
          ),
        ],
      ),
    );
  }
}

class _MatchSection extends ConsumerWidget {
  const _MatchSection({required this.listing, required this.isPaid});

  final JobListing listing;
  final bool isPaid;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = Theme.of(context).textTheme;
    final matchAsync = ref.watch(matchResultProvider(listing.id));

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Your match', style: text.titleLarge),
            const SizedBox(height: 12),
            matchAsync.when(
              loading: () => const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (error, _) => Text(error.toString(), style: text.bodyMedium),
              data: (match) => _MatchContent(match: match, isPaid: isPaid),
            ),
          ],
        ),
      ),
    );
  }
}

class _MatchContent extends StatelessWidget {
  const _MatchContent({required this.match, required this.isPaid});

  final MatchResult match;
  final bool isPaid;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;

    return Column(
      children: [
        Center(child: MatchScoreDial(matchPercent: match.matchPercent)),
        if (isPaid) ...[
          const SizedBox(height: 16),
          Text(match.reasoning, style: text.bodyMedium, textAlign: TextAlign.center),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerLeft,
            child: ExpandableSection(
              title: 'Gap breakdown & roadmap',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (match.matchedSkills.isNotEmpty) ...[
                    Text('Matched', style: text.labelMedium),
                    const SizedBox(height: 6),
                    _SkillChips(skills: match.matchedSkills, positive: true),
                    const SizedBox(height: 12),
                  ],
                  if (match.gapSkills.isNotEmpty) ...[
                    Text('Gap', style: text.labelMedium),
                    const SizedBox(height: 6),
                    _SkillChips(skills: match.gapSkills, positive: false),
                    const SizedBox(height: 12),
                  ],
                  if (match.upskillingRoadmap.isNotEmpty) ...[
                    Text('Upskilling roadmap', style: text.labelMedium),
                    const SizedBox(height: 6),
                    for (final step in match.upskillingRoadmap)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Padding(
                              padding: EdgeInsets.only(top: 2),
                              child: Icon(Icons.arrow_right_rounded, size: 18),
                            ),
                            Expanded(child: Text(step, style: text.bodyMedium)),
                          ],
                        ),
                      ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _SkillChips extends StatelessWidget {
  const _SkillChips({required this.skills, required this.positive});

  final List<String> skills;
  final bool positive;

  @override
  Widget build(BuildContext context) {
    final risk = Theme.of(context).extension<RiskColors>()!;
    final color = positive ? risk.verifiedLeaning : risk.highRisk;
    final bg = positive ? risk.verifiedLeaningBg : risk.highRiskBg;

    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        for (final skill in skills)
          Chip(
            label: Text(skill),
            labelStyle: Theme.of(context).textTheme.labelMedium?.copyWith(color: color),
            backgroundColor: bg,
            side: BorderSide.none,
            visualDensity: VisualDensity.compact,
          ),
      ],
    );
  }
}

class _TrustSection extends ConsumerWidget {
  const _TrustSection({required this.listing, required this.isPaid});

  final JobListing listing;
  final bool isPaid;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = Theme.of(context).textTheme;
    final scamAsync = ref.watch(scamAssessmentProvider(listing.id));

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Trust & safety', style: text.titleLarge),
            const SizedBox(height: 12),
            scamAsync.when(
              loading: () => const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (error, _) => Text(error.toString(), style: text.bodyMedium),
              data: (assessment) => _TrustContent(assessment: assessment, isPaid: isPaid),
            ),
          ],
        ),
      ),
    );
  }
}

class _TrustContent extends StatelessWidget {
  const _TrustContent({required this.assessment, required this.isPaid});

  final ScamAssessment assessment;
  final bool isPaid;

  static const _flagLabels = {
    'upfrontFeesRequested': 'Asks for upfront fees',
    'unrealisticSalary': 'Salary looks unrealistic',
    'noVerifiableDomain': 'No verifiable company domain',
    'urgencyLanguage': 'Uses urgency / pressure language',
    'whatsappOnlyContact': 'WhatsApp-only contact',
  };

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final flags = assessment.ruleFlags;
    final flagValues = {
      'upfrontFeesRequested': flags.upfrontFeesRequested,
      'unrealisticSalary': flags.unrealisticSalary,
      'noVerifiableDomain': flags.noVerifiableDomain,
      'urgencyLanguage': flags.urgencyLanguage,
      'whatsappOnlyContact': flags.whatsappOnlyContact,
    };

    return Column(
      children: [
        TrustBadgeChip(badge: assessment.trustBadge),
        const SizedBox(height: 16),
        Align(
          alignment: Alignment.centerLeft,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final entry in flagValues.entries)
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(
                    children: [
                      Icon(
                        entry.value ? Icons.flag_rounded : Icons.check_circle_outline_rounded,
                        size: 16,
                        color: entry.value
                            ? Theme.of(context).colorScheme.error
                            : Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                      const SizedBox(width: 8),
                      Text(_flagLabels[entry.key]!, style: text.bodyMedium),
                    ],
                  ),
                ),
            ],
          ),
        ),
        if (isPaid) ...[
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerLeft,
            child: Text(assessment.reasoning, style: text.bodyMedium),
          ),
        ],
      ],
    );
  }
}
