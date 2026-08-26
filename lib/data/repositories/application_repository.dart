import 'package:cloud_firestore/cloud_firestore.dart';
import '../../core/constants/firestore_collections.dart';
import '../../core/errors/failure.dart';
import '../models/application.dart';

/// Reads/writes `applications` — the user's own tracked status per
/// listing. Client-writable (see `firestore.rules`): unlike
/// matchResults/scamAssessments, there's no "forged verdict" risk in
/// letting a user say they applied to something.
class ApplicationRepository {
  ApplicationRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _collection =>
      _firestore.collection(FirestoreCollections.applications);

  Stream<List<Application>> watchApplications(String uid) {
    return _collection
        .where('userId', isEqualTo: uid)
        .orderBy('updatedAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) => Application.fromMap(doc.data(), id: doc.id)).toList())
        .handleError((Object error) {
      throw const NetworkFailure("Couldn't load your applications — check your internet and try again.");
    });
  }

  Stream<Application?> watchApplication({required String uid, required String listingId}) {
    final id = Application.buildId(userId: uid, listingId: listingId);
    return _collection.doc(id).snapshots().map((snapshot) {
      final data = snapshot.data();
      if (data == null) return null;
      return Application.fromMap(data, id: id);
    });
  }

  Future<void> setStatus({
    required String uid,
    required String listingId,
    required ApplicationStatus status,
  }) async {
    final id = Application.buildId(userId: uid, listingId: listingId);
    final now = DateTime.now();
    try {
      final existing = await _collection.doc(id).get();
      final createdAt = existing.data() != null
          ? Application.fromMap(existing.data()!, id: id).createdAt
          : now;
      await _collection.doc(id).set(
            Application(
              id: id,
              userId: uid,
              listingId: listingId,
              status: status,
              createdAt: createdAt,
              updatedAt: now,
            ).toMap(),
          );
    } on FirebaseException {
      throw const NetworkFailure("Couldn't save that — check your internet and try again.");
    }
  }

  Future<void> remove({required String uid, required String listingId}) async {
    final id = Application.buildId(userId: uid, listingId: listingId);
    try {
      await _collection.doc(id).delete();
    } on FirebaseException {
      throw const NetworkFailure("Couldn't remove that — check your internet and try again.");
    }
  }

  /// Used by account deletion — removes every application owned by [uid]
  /// before the account itself is deleted.
  Future<void> deleteAllForUser(String uid) async {
    final snapshot = await _collection.where('userId', isEqualTo: uid).get();
    final batch = _firestore.batch();
    for (final doc in snapshot.docs) {
      batch.delete(doc.reference);
    }
    await batch.commit();
  }
}
