import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/router/main_shell.dart';
import '../../../core/theme/risk_colors.dart';
import '../../../data/models/scam_assessment.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/trust_badge_chip.dart';
import '../providers/listings_providers.dart';
import 'widgets/job_listing_card.dart';

class ListingsFeedScreen extends ConsumerWidget {
  const ListingsFeedScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final listingsAsync = ref.watch(filteredListingsProvider);

    return Scaffold(
      appBar: AppBar(
        leading: buildDrawerButton(context),
        title: const Text('TrustHire'),
      ),
      body: Column(
        children: [
          const _FilterBar(),
          Expanded(
            child: listingsAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, stackTrace) => EmptyState(
                icon: Icons.wifi_off_rounded,
                title: "Couldn't load listings",
                message: error.toString(),
                actionLabel: 'Retry',
                onAction: () => ref.invalidate(listingsStreamProvider),
              ),
              data: (listings) {
                if (listings.isEmpty) {
                  return const EmptyState(
                    icon: Icons.inbox_outlined,
                    title: 'No listings match these filters',
                    message: 'Try clearing a filter above, or check back soon for new listings.',
                  );
                }
                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                  itemCount: listings.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final listing = listings[index];
                    return JobListingCard(
                      listing: listing,
                      staggerIndex: index,
                      onTap: () => context.push('/listings/${listing.id}'),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// Trust-badge + remote-only filter row. Purely client-side over
/// [filteredListingsProvider] — see that provider for why (the badge is
/// already computed per-card by [ScamRuleEngine], no extra network cost).
class _FilterBar extends ConsumerWidget {
  const _FilterBar();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final risk = Theme.of(context).extension<RiskColors>()!;
    final trustFilter = ref.watch(trustBadgeFilterProvider);
    final remoteOnly = ref.watch(remoteOnlyFilterProvider);

    Color colorFor(TrustBadge badge) => switch (badge) {
          TrustBadge.verifiedLeaning => risk.verifiedLeaning,
          TrustBadge.caution => risk.caution,
          TrustBadge.highRisk => risk.highRisk,
        };

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            FilterChip(
              label: const Text('Remote'),
              avatar: const Icon(Icons.wifi, size: 16),
              selected: remoteOnly,
              onSelected: (value) => ref.read(remoteOnlyFilterProvider.notifier).state = value,
            ),
            const SizedBox(width: 8),
            for (final badge in TrustBadge.values) ...[
              FilterChip(
                label: Text(TrustBadgeChip.labelFor(badge)),
                avatar: Icon(TrustBadgeChip.iconFor(badge), size: 16, color: colorFor(badge)),
                selected: trustFilter == badge,
                onSelected: (selected) =>
                    ref.read(trustBadgeFilterProvider.notifier).state = selected ? badge : null,
              ),
              const SizedBox(width: 8),
            ],
          ],
        ),
      ),
    );
  }
}
