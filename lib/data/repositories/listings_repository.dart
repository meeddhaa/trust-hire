import 'package:cloud_firestore/cloud_firestore.dart';
import '../../core/constants/firestore_collections.dart';
import '../../core/errors/failure.dart';
import '../models/job_listing.dart';

/// Reads the curated `listings` collection — client read-only, seeded
/// server-side (see `firestore.rules` and `data/seed/`, step 5).
class ListingsRepository {
  ListingsRepository({FirebaseFirestore? firestore}) : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  /// Newest-first feed. A `StreamProvider` over this is what backs pull-to
  /// -refresh-free live updates — if the seed script adds a listing while
  /// the app is open, it just appears.
  Stream<List<JobListing>> watchListings() {
    return _firestore
        .collection(FirestoreCollections.listings)
        .orderBy('postedAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) => JobListing.fromMap(doc.data(), id: doc.id)).toList())
        .handleError((Object error) {
      throw const NetworkFailure("Couldn't load listings — check your internet and try again.");
    });
  }

  Future<JobListing?> getListing(String listingId) async {
    try {
      final snapshot = await _firestore.collection(FirestoreCollections.listings).doc(listingId).get();
      final data = snapshot.data();
      if (data == null) return null;
      return JobListing.fromMap(data, id: snapshot.id);
    } on FirebaseException {
      throw const NetworkFailure("Couldn't load that listing — check your internet and try again.");
    }
  }
}
