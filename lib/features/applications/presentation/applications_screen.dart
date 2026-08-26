import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/router/main_shell.dart';
import '../../../core/theme/risk_colors.dart';
import '../../../data/models/application.dart';
import '../../../shared/widgets/company_avatar.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../listing_detail/providers/listing_detail_providers.dart';
import '../providers/applications_providers.dart';

/// Tracks the user's own self-reported progress per listing (interested →
/// applied → interviewing → offer/rejected). Not verified by anything —
/// no bdapps/email integration reads real application status — this is
/// the user's own tracking, same spirit as a personal kanban board.
class ApplicationsScreen extends ConsumerWidget {
  const ApplicationsScreen({super.key});

  static const _statusLabels = {
    ApplicationStatus.interested: 'Interested',
    ApplicationStatus.applied: 'Applied',
    ApplicationStatus.interviewing: 'Interviewing',
    ApplicationStatus.offer: 'Offer',
    ApplicationStatus.rejected: 'Rejected',
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final applicationsAsync = ref.watch(applicationsStreamProvider);

    return Scaffold(
      appBar: AppBar(leading: buildDrawerButton(context), title: const Text('Applications')),
      body: applicationsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => EmptyState(
          icon: Icons.wifi_off_rounded,
          title: "Couldn't load applications",
          message: error.toString(),
        ),
        data: (applications) {
          if (applications.isEmpty) {
            return const EmptyState(
              icon: Icons.work_outline_rounded,
              title: 'Nothing tracked yet',
              message: 'Open a listing and mark it "Interested" or "Applied" to track it here.',
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: applications.length,
            separatorBuilder: (_, _) => const SizedBox(height: 10),
            itemBuilder: (context, index) => _ApplicationTile(application: applications[index]),
          );
        },
      ),
    );
  }
}

class _ApplicationTile extends ConsumerWidget {
  const _ApplicationTile({required this.application});

  final Application application;

  /// Color-codes the status pill so progress reads at a glance down the
  /// list, not just from the label text — reusing the same risk-scale
  /// colors as trust badges for offer/rejected (they're the same
  /// "good/bad outcome" shape), the brand accent for the in-progress
  /// "applied" state, and a neutral tone for "interested" (nothing has
  /// actually happened yet).
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
  Widget build(BuildContext context, WidgetRef ref) {
    final text = Theme.of(context).textTheme;
    final listingAsync = ref.watch(listingByIdProvider(application.listingId));
    final risk = Theme.of(context).extension<RiskColors>()!;
    final (fg, bg) = _colorsFor(application.status, risk, Theme.of(context).colorScheme);

    return Card(
      child: ListTile(
        leading: listingAsync.value?.company != null
            ? CompanyAvatar(company: listingAsync.value!.company, size: 40)
            : null,
        title: listingAsync.when(
          data: (listing) => Text(listing?.title ?? 'Listing no longer available'),
          loading: () => const Text('Loading…'),
          error: (_, _) => const Text('Listing no longer available'),
        ),
        subtitle: listingAsync.value?.company != null ? Text(listingAsync.value!.company) : null,
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(8)),
          child: Text(
            ApplicationsScreen._statusLabels[application.status]!,
            style: text.labelSmall?.copyWith(color: fg, fontWeight: FontWeight.w600),
          ),
        ),
        onTap: () => context.push('/listings/${application.listingId}'),
      ),
    );
  }
}
