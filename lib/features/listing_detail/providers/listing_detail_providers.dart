import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/errors/failure.dart';
import '../../../core/providers/repository_providers.dart';
import '../../../core/providers/session_providers.dart';
import '../../../data/models/job_listing.dart';
import '../../../data/models/match_result.dart';
import '../../../data/models/scam_assessment.dart';
import '../../listings/providers/listings_providers.dart';

/// Looks the listing up in the already-loaded feed first (no extra
/// Firestore read for the common case of tapping a card you're already
/// looking at), falling back to a direct fetch for a deep link or a feed
/// that hasn't loaded yet.
final listingByIdProvider = FutureProvider.family<JobListing?, String>((ref, listingId) async {
  final listings = ref.watch(listingsStreamProvider).valueOrNull;
  if (listings != null) {
    for (final listing in listings) {
      if (listing.id == listingId) return listing;
    }
  }
  return ref.watch(listingsRepositoryProvider).getListing(listingId);
});

/// The match result — this is what makes `MatchScoreDial` on this screen
/// real instead of decorative. `.family` + the default `autoDispose`
/// caching Riverpod gives `FutureProvider` means re-opening the same
/// listing in the same session doesn't even re-run this provider, on top
/// of `MatchRepository`'s own Firestore-level cache.
final matchResultProvider = FutureProvider.family<MatchResult, String>((ref, listingId) async {
  final uid = ref.watch(currentUidProvider);
  if (uid == null) throw const AuthFailure('Please sign in again.');
  return ref.watch(matchRepositoryProvider).getMatch(uid: uid, listingId: listingId);
});

final scamAssessmentProvider = FutureProvider.family<ScamAssessment, String>((ref, listingId) {
  return ref.watch(scamRepositoryProvider).getAssessment(listingId);
});
