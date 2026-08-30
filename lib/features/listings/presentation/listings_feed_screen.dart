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

/// A pure listings browser — search, filters, cards. The personalized
/// "home" greeting used to live here but now belongs to the Dashboard tab
/// (see `dashboard_screen.dart`); Jobs doing double duty as both home and
/// browser was explicit feedback to fix, not a stylistic preference.
class ListingsFeedScreen extends ConsumerWidget {
  const ListingsFeedScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final listingsAsync = ref.watch(filteredListingsProvider);
    // Real listing count for the header line below — never a fabricated
    // stat like the reference's "3.2k impressions" (nothing in this app's
    // data model supports that), just what's actually in the feed.
    final totalListings = ref.watch(listingsStreamProvider).valueOrNull?.length;

    return Scaffold(
      appBar: AppBar(
        leading: buildDrawerButton(context),
        title: const Text('Jobs'),
      ),
      body: Column(
        children: [
          _CountHeader(totalListings: totalListings),
          const _SearchField(),
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
                  separatorBuilder: (_, _) => const SizedBox(height: 16),
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

/// A warm, personal opener — borrowed structurally from the reference's
/// Just the real listing count — the personalized greeting moved to the
/// Dashboard tab (see this file's class doc comment).
class _CountHeader extends StatelessWidget {
  const _CountHeader({required this.totalListings});

  final int? totalListings;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final subtitle = totalListings == null
        ? 'Loading listings…'
        : '$totalListings listing${totalListings == 1 ? '' : 's'} to explore';

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
      child: Text(subtitle, style: text.bodyMedium?.copyWith(color: scheme.onSurfaceVariant)),
    );
  }
}

/// Live client-side title/company/location search over the feed already
/// held in memory (see `searchQueryProvider`) — a real, working version of
/// the reference's search affordance, not a decorative icon.
class _SearchField extends ConsumerWidget {
  const _SearchField();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final query = ref.watch(searchQueryProvider);
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 4),
      child: TextField(
        onChanged: (value) => ref.read(searchQueryProvider.notifier).state = value,
        decoration: InputDecoration(
          hintText: 'Search job title, company, location…',
          prefixIcon: const Icon(Icons.search_rounded),
          suffixIcon: query.isEmpty
              ? null
              : IconButton(
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () => ref.read(searchQueryProvider.notifier).state = '',
                ),
        ),
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
