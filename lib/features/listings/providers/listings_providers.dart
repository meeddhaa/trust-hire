import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers/repository_providers.dart';
import '../../../data/models/job_listing.dart';
import '../../../data/models/scam_assessment.dart';
import '../../../data/services/scam_rule_engine.dart';

final listingsStreamProvider = StreamProvider<List<JobListing>>((ref) {
  return ref.watch(listingsRepositoryProvider).watchListings();
});

/// Trust-badge filter for the feed — `null` means "all badges". Client-side
/// only: the same [ScamRuleEngine] the feed card already runs per-listing
/// to render its badge, just used to filter instead of just to color.
final trustBadgeFilterProvider = StateProvider<TrustBadge?>((ref) => null);

/// "Remote only" toggle for the feed, alongside the trust-badge filter.
final remoteOnlyFilterProvider = StateProvider<bool>((ref) => false);

/// Free-text search over title/company/location — client-side, same
/// reasoning as the other filters (the whole feed is already in memory
/// from one Firestore listen; no separate search backend/index needed for
/// a dataset this size).
final searchQueryProvider = StateProvider<String>((ref) => '');

/// The feed list after applying search + both filters — kept as its own
/// provider (rather than filtering inline in the screen) so the screen's
/// `build` stays a straight `.when` over one async value.
final filteredListingsProvider = Provider<AsyncValue<List<JobListing>>>((ref) {
  final trustFilter = ref.watch(trustBadgeFilterProvider);
  final remoteOnly = ref.watch(remoteOnlyFilterProvider);
  final query = ref.watch(searchQueryProvider).trim().toLowerCase();
  return ref.watch(listingsStreamProvider).whenData((listings) {
    return listings.where((listing) {
      if (remoteOnly && !listing.isRemote) return false;
      if (trustFilter != null && ScamRuleEngine.assess(listing).trustBadge != trustFilter) return false;
      if (query.isNotEmpty &&
          !listing.title.toLowerCase().contains(query) &&
          !listing.company.toLowerCase().contains(query) &&
          !listing.location.toLowerCase().contains(query)) {
        return false;
      }
      return true;
    }).toList();
  });
});
