import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../core/errors/failure.dart';
import '../../../core/providers/repository_providers.dart';
import '../../../core/providers/session_providers.dart';
import '../../../core/theme/risk_colors.dart';
import '../../../data/models/application.dart';
import '../../../data/models/job_listing.dart';
import '../../../data/models/match_result.dart';
import '../../../data/models/resume_tailor_result.dart';
import '../../../data/models/scam_assessment.dart';
import '../../../shared/widgets/company_avatar.dart';
import '../../../shared/widgets/expandable_section.dart';
import '../../../shared/widgets/match_score_dial.dart';
import '../../../shared/widgets/trust_badge_chip.dart';
import '../../applications/providers/applications_providers.dart';
import '../../saved_jobs/providers/saved_jobs_providers.dart';
import '../providers/listing_detail_providers.dart';
import '../providers/resume_tailor_providers.dart';
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
    final listing = listingAsync.valueOrNull;
    final uid = ref.read(currentUidProvider);
    // A plain top bar (not a transparent one floating over the photo) —
    // matches the reference's "< Details 🔖" bar, which sits on its own
    // plain background above a separately inset photo card, not overlaid
    // on it.
    final isSaved = listing == null ? false : ref.watch(isJobSavedProvider(listing.id)).valueOrNull ?? false;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Details'),
        actions: [
          if (listing != null)
            IconButton(
              icon: Icon(isSaved ? Icons.bookmark : Icons.bookmark_border),
              color: isSaved ? Theme.of(context).colorScheme.primary : null,
              tooltip: isSaved ? 'Remove from saved' : 'Save for later',
              onPressed: uid == null
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
      // Pinned, not just the last item in the scroll content — matches
      // the reference's fixed "Apply for this Job" button. We redirect to
      // the original posting rather than hosting our own application
      // flow, so this is the closest equivalent action.
      bottomNavigationBar: listing == null
          ? null
          : SafeArea(
              minimum: const EdgeInsets.fromLTRB(20, 8, 20, 16),
              child: ElevatedButton.icon(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => SourceWebviewScreen(url: listing.sourceUrl, title: listing.company),
                  ),
                ),
                style: ElevatedButton.styleFrom(minimumSize: const Size.fromHeight(52)),
                icon: const Icon(Icons.open_in_new_rounded),
                label: const Text('View original posting'),
              ),
            ),
    );
  }
}

class _ListingDetailBody extends ConsumerWidget {
  const _ListingDetailBody({required this.listing});

  final JobListing listing;

  static final _salaryFormat = NumberFormat.decimalPattern();

  String? _salaryLine() {
    final min = listing.salaryMin;
    final max = listing.salaryMax;
    if (min == null && max == null) return null;
    final currency = listing.salaryCurrency;
    if (min != null && max != null) {
      return '${_salaryFormat.format(min)}–${_salaryFormat.format(max)} $currency / month';
    }
    return '${_salaryFormat.format(min ?? max)} $currency / month';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final subscription = ref.watch(currentSubscriptionProvider).valueOrNull;
    final isPaid = subscription?.isPaid ?? false;
    final salaryLine = _salaryLine();

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Inset, padded photo panel — not full-bleed under the app bar —
          // matching the reference's separately-carded photo below its
          // plain top bar. Flat color instead of a real photo; see
          // `job_listing_card.dart`'s doc comment for why.
          _PhotoPanel(listing: listing),
          const SizedBox(height: 18),
          Text(listing.title, style: text.headlineMedium),
          const SizedBox(height: 4),
          Text(
            '${listing.company} · ${listing.location}${listing.isRemote ? ' · Remote' : ''}',
            style: text.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
          ),
          if (salaryLine != null) ...[
            const SizedBox(height: 8),
            Text(
              salaryLine,
              style: text.titleLarge?.copyWith(color: scheme.primary, fontWeight: FontWeight.w800),
            ),
          ],
          const SizedBox(height: 20),
          _ApplicationStatusRow(listingId: listing.id),
          const SizedBox(height: 20),

          _MatchSection(listing: listing, isPaid: isPaid),
          const SizedBox(height: 20),
          _TrustSection(listing: listing, isPaid: isPaid),
          const SizedBox(height: 20),

          // A single grouped, bordered list of "more detail" rows — the
          // reference's "About the Company / Responsibilities /
          // Requirements / Benefits" accordion pattern. Only one row for
          // now (see that widget's doc comment for why the others aren't
          // synthesized), but styled as the same kind of container so
          // adding more later doesn't need a redesign.
          _MoreDetailsCard(listing: listing),
          const SizedBox(height: 20),

          if (isPaid) ...[
            _ResumeTailorSection(listing: listing),
            const SizedBox(height: 20),
          ],

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

          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: () => context.go('/job-coach?listingId=${listing.id}'),
            icon: const Icon(Icons.school_outlined),
            label: const Text('Get Job Coach advice'),
          ),
        ],
      ),
    );
  }
}

/// The inset colored panel standing in for the reference's product photo
/// — see `job_listing_card.dart`'s doc comment for why a flat color
/// (rather than a stock/generic photo) is the honest choice here. A large
/// low-opacity building glyph gives it a bit of visual texture instead of
/// being a completely flat color block.
class _PhotoPanel extends StatelessWidget {
  const _PhotoPanel({required this.listing});

  final JobListing listing;

  @override
  Widget build(BuildContext context) {
    final panelColor = CompanyAvatar.colorFor(listing.company);
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: AspectRatio(
        aspectRatio: 16 / 10,
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [panelColor, Color.lerp(panelColor, Colors.black, 0.35)!],
            ),
          ),
          child: Center(
            child: Icon(
              Icons.apartment_rounded,
              size: 56,
              color: Colors.white.withValues(alpha: 0.35),
            ),
          ),
        ),
      ),
    );
  }
}

class _ApplicationStatusRow extends ConsumerWidget {
  const _ApplicationStatusRow({required this.listingId});

  final String listingId;

  static const _labels = {
    ApplicationStatus.interested: 'Interested',
    ApplicationStatus.applied: 'Applied',
    ApplicationStatus.interviewing: 'Interviewing',
    ApplicationStatus.offer: 'Offer',
    ApplicationStatus.rejected: 'Rejected',
  };

  /// Same status → color mapping as the Applications list tile (see
  /// `applications_screen.dart`'s `_ApplicationTile._colorsFor`) — kept in
  /// sync manually rather than shared, since pulling it into a common
  /// widget file for two call sites wasn't worth the indirection yet.
  static (Color, Color) _colorsFor(ApplicationStatus? status, RiskColors risk, ColorScheme scheme) {
    return switch (status) {
      null => (scheme.onSurfaceVariant, scheme.surfaceContainerHighest),
      ApplicationStatus.interested => (scheme.onSurfaceVariant, scheme.surfaceContainerHighest),
      ApplicationStatus.applied => (scheme.primary, scheme.primary.withValues(alpha: 0.12)),
      ApplicationStatus.interviewing => (risk.caution, risk.cautionBg),
      ApplicationStatus.offer => (risk.verifiedLeaning, risk.verifiedLeaningBg),
      ApplicationStatus.rejected => (risk.highRisk, risk.highRiskBg),
    };
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = Theme.of(context).textTheme;
    final application = ref.watch(applicationForListingProvider(listingId)).valueOrNull;
    final uid = ref.read(currentUidProvider);
    final risk = Theme.of(context).extension<RiskColors>()!;
    final (fg, bg) = _colorsFor(application?.status, risk, Theme.of(context).colorScheme);

    // A filled, color-coded card rather than an inline text label + small
    // dropdown arrow — this is the button users reported not noticing at
    // all, so it needs to read as a primary action, not a footnote.
    return Material(
      color: bg,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: uid == null
            ? null
            : () => _showStatusPicker(context, ref, uid, application?.status),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Icon(Icons.flag_outlined, size: 20, color: fg),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Application status', style: text.labelSmall?.copyWith(color: fg)),
                    const SizedBox(height: 2),
                    Text(
                      application == null ? 'Not tracked — tap to add' : _labels[application.status]!,
                      style: text.titleMedium?.copyWith(color: fg, fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
              ),
              Icon(Icons.keyboard_arrow_down_rounded, color: fg),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showStatusPicker(
    BuildContext context,
    WidgetRef ref,
    String uid,
    ApplicationStatus? current,
  ) async {
    final selected = await showModalBottomSheet<ApplicationStatus>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 16, 16, 4),
              child: Align(alignment: Alignment.centerLeft, child: Text('Track this application')),
            ),
            for (final status in ApplicationStatus.values)
              ListTile(
                leading: Icon(current == status ? Icons.radio_button_checked : Icons.radio_button_unchecked),
                title: Text(_labels[status]!),
                onTap: () => Navigator.pop(sheetContext, status),
              ),
          ],
        ),
      ),
    );
    if (selected == null) return;
    await ref.read(applicationRepositoryProvider).setStatus(uid: uid, listingId: listingId, status: selected);
  }
}

/// Small icon-in-circle + title row, echoing the profile screen's info-row
/// language — used as the header for every card on this screen so the
/// page reads as a set of consistent, scannable sections rather than each
/// card inventing its own header style.
class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.icon, required this.title});

  final IconData icon;
  final String title;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return Row(
      children: [
        CircleAvatar(
          radius: 16,
          backgroundColor: scheme.primary.withValues(alpha: 0.12),
          child: Icon(icon, size: 16, color: scheme.primary),
        ),
        const SizedBox(width: 10),
        Text(title, style: text.titleLarge),
      ],
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
            const _SectionHeader(icon: Icons.insights_outlined, title: 'Your match'),
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
            const _SectionHeader(icon: Icons.shield_outlined, title: 'Trust & safety'),
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

/// A grouped, bordered list of expandable "more detail" rows — the
/// reference's "About the Company / Responsibilities / Requirements /
/// Benefits" accordion, as one container rather than separate floating
/// cards. Only "Job description" for now: JSearch's listings arrive as
/// one unstructured description blob, not pre-split into those
/// categories, and synthetically splitting it would risk misrepresenting
/// what the original posting actually says. Expanded by default, echoing
/// the reference's "About the Company" row (its only row shown open).
class _MoreDetailsCard extends StatelessWidget {
  const _MoreDetailsCard({required this.listing});

  final JobListing listing;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        child: ExpandableSection(
          title: 'Job description',
          initiallyExpanded: true,
          child: Text(listing.description, style: text.bodyMedium),
        ),
      ),
    );
  }
}

/// Paid-tier-only, on-demand: tapping the button calls the Worker's
/// `/v1/resume-tailor` endpoint (a heavier Gemini call, reading the
/// uploaded resume PDF directly — see `worker/src/index.ts`), rather than
/// firing eagerly like the match/scam sections above.
class _ResumeTailorSection extends ConsumerWidget {
  const _ResumeTailorSection({required this.listing});

  final JobListing listing;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = Theme.of(context).textTheme;
    final state = ref.watch(resumeTailorControllerProvider);

    ref.listen(resumeTailorControllerProvider, (previous, next) {
      final error = next.error;
      if (error == null) return;
      if (error is NotFoundFailure) return; // handled inline below, not a snackbar
      final message = error is Failure ? error.message : 'Something went wrong — please try again.';
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(message)));
    });

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _SectionHeader(icon: Icons.auto_fix_high_outlined, title: 'Tailor my resume'),
            const SizedBox(height: 4),
            Text(
              'Grounded in your uploaded resume — see Settings > Resume.',
              style: text.bodySmall,
            ),
            const SizedBox(height: 12),
            state.when(
              data: (result) {
                if (result == null || result.listingId != listing.id) {
                  return ElevatedButton(
                    onPressed: () => ref.read(resumeTailorControllerProvider.notifier).tailorFor(listing.id),
                    child: const Text('Tailor for this job'),
                  );
                }
                return _ResumeTailorContent(result: result);
              },
              loading: () => const Center(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: CircularProgressIndicator(),
                ),
              ),
              error: (error, _) {
                if (error is NotFoundFailure) {
                  return Text(error.message, style: text.bodyMedium);
                }
                return ElevatedButton(
                  onPressed: () => ref.read(resumeTailorControllerProvider.notifier).tailorFor(listing.id),
                  child: const Text('Try again'),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _ResumeTailorContent extends StatelessWidget {
  const _ResumeTailorContent({required this.result});

  final ResumeTailorResult result;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(result.tailoredSummary, style: text.bodyMedium),
        if (result.emphasize.isNotEmpty) ...[
          const SizedBox(height: 14),
          Text('Emphasize', style: text.labelMedium),
          const SizedBox(height: 6),
          for (final item in result.emphasize)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text('•  $item', style: text.bodyMedium),
            ),
        ],
        if (result.addKeywords.isNotEmpty) ...[
          const SizedBox(height: 14),
          Text('Consider adding', style: text.labelMedium),
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [for (final keyword in result.addKeywords) Chip(label: Text(keyword))],
          ),
        ],
        if (result.suggestions.isNotEmpty) ...[
          const SizedBox(height: 14),
          Text('Suggestions', style: text.labelMedium),
          const SizedBox(height: 6),
          for (final suggestion in result.suggestions)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text('•  $suggestion', style: text.bodyMedium),
            ),
        ],
      ],
    );
  }
}
