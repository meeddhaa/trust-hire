import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/router/main_shell.dart';
import '../../../shared/widgets/empty_state.dart';
import '../providers/listings_providers.dart';
import 'widgets/job_listing_card.dart';

class ListingsFeedScreen extends ConsumerWidget {
  const ListingsFeedScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final listingsAsync = ref.watch(listingsStreamProvider);

    return Scaffold(
      appBar: AppBar(
        leading: buildDrawerButton(context),
        title: const Text('TrustHire'),
      ),
      body: listingsAsync.when(
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
              title: 'No listings yet',
              message: 'Check back soon — new listings are added regularly.',
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
    );
  }
}
