import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers/repository_providers.dart';
import '../../../core/providers/session_providers.dart';
import '../../../data/models/saved_job.dart';

final savedJobsStreamProvider = StreamProvider<List<SavedJob>>((ref) {
  final uid = ref.watch(currentUidProvider);
  if (uid == null) return Stream.value(const []);
  return ref.watch(savedJobRepositoryProvider).watchSavedJobs(uid);
});

/// Whether the current listing is saved — used by the bookmark toggle on
/// the listing card/detail.
final isJobSavedProvider = StreamProvider.family<bool, String>((ref, listingId) {
  final uid = ref.watch(currentUidProvider);
  if (uid == null) return Stream.value(false);
  return ref.watch(savedJobRepositoryProvider).watchIsSaved(uid: uid, listingId: listingId);
});
