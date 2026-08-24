import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers/repository_providers.dart';
import '../../../data/models/job_listing.dart';

final listingsStreamProvider = StreamProvider<List<JobListing>>((ref) {
  return ref.watch(listingsRepositoryProvider).watchListings();
});
