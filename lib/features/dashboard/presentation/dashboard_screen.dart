import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/providers/session_providers.dart';
import '../../../core/router/main_shell.dart';
import '../../../core/theme/risk_colors.dart';
import '../../../data/models/application.dart';
import '../../applications/providers/applications_providers.dart';
import '../../listings/providers/listings_providers.dart';
import '../../saved_jobs/providers/saved_jobs_providers.dart';

/// The app's actual home — separate from the Jobs tab (a pure listings
/// browser: search, filters, cards) per explicit feedback that Jobs was
/// doing double duty. Everything shown here is a real count from data
/// already loaded elsewhere (applications, saved jobs, listings) — no
/// fabricated engagement stats, same principle the Jobs feed's header
/// already followed.
class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  static String _greeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning';
    if (hour < 17) return 'Good afternoon';
    return 'Good evening';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final applications = ref.watch(applicationsStreamProvider).valueOrNull ?? const <Application>[];
    final savedCount = ref.watch(savedJobsStreamProvider).valueOrNull?.length;
    final listingsCount = ref.watch(listingsStreamProvider).valueOrNull?.length;
    final displayName = ref.watch(currentProfileProvider).valueOrNull?.displayName ?? '';
    final firstName = displayName.trim().isEmpty ? null : displayName.trim().split(' ').first;

    return Scaffold(
      appBar: AppBar(leading: buildDrawerButton(context)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
        children: [
          Text(
            firstName == null ? _greeting() : '${_greeting()}, $firstName',
            style: text.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
          ),
          const SizedBox(height: 6),
          Text('Your job search, at a glance', style: text.headlineMedium),
          const SizedBox(height: 20),

          Row(
            children: [
              Expanded(
                child: _StatCard(
                  icon: Icons.assignment_outlined,
                  value: '${applications.length}',
                  label: 'Applications',
                  onTap: () => context.go('/applications'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _StatCard(
                  icon: Icons.bookmark_border_rounded,
                  value: savedCount == null ? '—' : '$savedCount',
                  label: 'Saved',
                  onTap: () => context.go('/saved'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _StatCard(
                  icon: Icons.work_outline_rounded,
                  value: listingsCount == null ? '—' : '$listingsCount',
                  label: 'Listings',
                  onTap: () => context.go('/listings'),
                ),
              ),
            ],
          ),

          if (applications.isNotEmpty) ...[
            const SizedBox(height: 24),
            Text('Application status', style: text.titleMedium),
            const SizedBox(height: 10),
            _StatusBreakdownCard(applications: applications),
          ],

          const SizedBox(height: 24),
          Text('Quick actions', style: text.titleMedium),
          const SizedBox(height: 10),
          _QuickActionRow(
            icon: Icons.work_outline_rounded,
            label: 'Browse jobs',
            onTap: () => context.go('/listings'),
          ),
          const SizedBox(height: 10),
          _QuickActionRow(
            icon: Icons.description_outlined,
            label: 'Update resume',
            onTap: () => context.push('/resume'),
          ),
          const SizedBox(height: 10),
          _QuickActionRow(
            icon: Icons.school_outlined,
            label: 'Ask Job Coach',
            onTap: () => context.go('/job-coach'),
          ),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({required this.icon, required this.value, required this.label, required this.onTap});

  final IconData icon;
  final String value;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(24),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: scheme.primary, size: 20),
              const SizedBox(height: 10),
              Text(value, style: text.headlineSmall),
              const SizedBox(height: 2),
              Text(label, style: text.bodySmall),
            ],
          ),
        ),
      ),
    );
  }
}

/// Small colored-count breakdown by status — same status→color mapping as
/// `applications_screen.dart`'s `_ApplicationTile` and the listing
/// detail's track control, kept in sync manually across all three rather
/// than shared (same reasoning noted at both of those call sites: not
/// worth the indirection yet for three call sites this small).
class _StatusBreakdownCard extends StatelessWidget {
  const _StatusBreakdownCard({required this.applications});

  final List<Application> applications;

  static const _labels = {
    ApplicationStatus.interested: 'Interested',
    ApplicationStatus.applied: 'Applied',
    ApplicationStatus.interviewing: 'Interviewing',
    ApplicationStatus.offer: 'Offer',
    ApplicationStatus.rejected: 'Rejected',
  };

  static (Color, Color) _colorsFor(ApplicationStatus status, RiskColors risk, ColorScheme scheme) {
    return switch (status) {
      ApplicationStatus.interested => (scheme.onSurfaceVariant, scheme.surfaceContainerHighest),
      ApplicationStatus.applied => (scheme.primary, scheme.primary.withValues(alpha: 0.12)),
      ApplicationStatus.interviewing => (risk.caution, risk.cautionBg),
      ApplicationStatus.offer => (risk.verifiedLeaning, risk.verifiedLeaningBg),
      ApplicationStatus.rejected => (risk.highRisk, risk.highRiskBg),
    };
  }

  @override
  Widget build(BuildContext context) {
    final risk = Theme.of(context).extension<RiskColors>()!;
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final counts = <ApplicationStatus, int>{};
    for (final application in applications) {
      counts[application.status] = (counts[application.status] ?? 0) + 1;
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            for (final status in ApplicationStatus.values)
              if (counts[status] != null)
                Builder(
                  builder: (context) {
                    final (fg, bg) = _colorsFor(status, risk, scheme);
                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20)),
                      child: Text(
                        '${counts[status]} ${_labels[status]}',
                        style: text.labelMedium?.copyWith(color: fg, fontWeight: FontWeight.w700),
                      ),
                    );
                  },
                ),
          ],
        ),
      ),
    );
  }
}

class _QuickActionRow extends StatelessWidget {
  const _QuickActionRow({required this.icon, required this.label, required this.onTap});

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(24),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              CircleAvatar(
                radius: 16,
                backgroundColor: scheme.primary.withValues(alpha: 0.12),
                child: Icon(icon, size: 16, color: scheme.primary),
              ),
              const SizedBox(width: 12),
              Expanded(child: Text(label, style: text.titleSmall)),
              Icon(Icons.chevron_right_rounded, color: scheme.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }
}
