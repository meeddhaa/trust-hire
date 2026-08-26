import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers/repository_providers.dart';
import '../../../core/providers/session_providers.dart';
import '../../../data/models/application.dart';

final applicationsStreamProvider = StreamProvider<List<Application>>((ref) {
  final uid = ref.watch(currentUidProvider);
  if (uid == null) return Stream.value(const []);
  return ref.watch(applicationRepositoryProvider).watchApplications(uid);
});

/// Live status for one listing — used by the listing detail screen's
/// "Track application" control, family-keyed so each listing detail view
/// only watches its own doc.
final applicationForListingProvider = StreamProvider.family<Application?, String>((ref, listingId) {
  final uid = ref.watch(currentUidProvider);
  if (uid == null) return Stream.value(null);
  return ref.watch(applicationRepositoryProvider).watchApplication(uid: uid, listingId: listingId);
});
