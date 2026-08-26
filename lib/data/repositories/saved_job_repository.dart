import 'package:cloud_firestore/cloud_firestore.dart';
import '../../core/constants/firestore_collections.dart';
import '../../core/errors/failure.dart';
import '../models/saved_job.dart';

/// Reads/writes `savedJobs` — the user's own bookmarks. Client-writable,
/// same reasoning as `ApplicationRepository`.
class SavedJobRepository {
  SavedJobRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _collection =>
      _firestore.collection(FirestoreCollections.savedJobs);

  Stream<List<SavedJob>> watchSavedJobs(String uid) {
    return _collection
        .where('userId', isEqualTo: uid)
        .orderBy('savedAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) => SavedJob.fromMap(doc.data(), id: doc.id)).toList())
        .handleError((Object error) {
      throw const NetworkFailure("Couldn't load your saved jobs — check your internet and try again.");
    });
  }

  Stream<bool> watchIsSaved({required String uid, required String listingId}) {
    final id = SavedJob.buildId(userId: uid, listingId: listingId);
    return _collection.doc(id).snapshots().map((snapshot) => snapshot.exists);
  }

  Future<void> save({required String uid, required String listingId}) async {
    final id = SavedJob.buildId(userId: uid, listingId: listingId);
    try {
      await _collection
          .doc(id)
          .set(SavedJob(id: id, userId: uid, listingId: listingId, savedAt: DateTime.now()).toMap());
    } on FirebaseException {
      throw const NetworkFailure("Couldn't save that job — check your internet and try again.");
    }
  }

  Future<void> unsave({required String uid, required String listingId}) async {
    final id = SavedJob.buildId(userId: uid, listingId: listingId);
    try {
      await _collection.doc(id).delete();
    } on FirebaseException {
      throw const NetworkFailure("Couldn't remove that — check your internet and try again.");
    }
  }

  /// Used by account deletion — see `ApplicationRepository.deleteAllForUser`.
  Future<void> deleteAllForUser(String uid) async {
    final snapshot = await _collection.where('userId', isEqualTo: uid).get();
    final batch = _firestore.batch();
    for (final doc in snapshot.docs) {
      batch.delete(doc.reference);
    }
    await batch.commit();
  }
}
