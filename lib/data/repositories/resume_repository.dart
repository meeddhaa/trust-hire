import 'package:cloud_firestore/cloud_firestore.dart';
import '../../core/constants/firestore_collections.dart';
import '../../core/errors/failure.dart';
import '../models/resume.dart';

/// Reads/writes `users/{uid}/resumes/{resumeId}` — see `Resume`'s doc
/// comment for why exactly one is ever "active" and what that mirrors
/// onto the parent profile doc.
class ResumeRepository {
  ResumeRepository({FirebaseFirestore? firestore}) : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> _collection(String uid) => _firestore
      .collection(FirestoreCollections.users)
      .doc(uid)
      .collection(FirestoreCollections.resumes);

  Stream<List<Resume>> watchResumes(String uid) {
    return _collection(uid).orderBy('createdAt', descending: true).snapshots().map((snapshot) {
      return snapshot.docs.map((doc) => Resume.fromMap(doc.data(), id: doc.id)).toList();
    });
  }

  /// Adds a new named resume, not yet active — the caller (see
  /// `ResumeController.addResume`) sets it active as a separate step once
  /// the doc exists, so `setActive`'s "clear every other active flag"
  /// logic has a stable id to target.
  Future<String> addResume({required String uid, required String name, required String base64}) async {
    try {
      final now = DateTime.now();
      final doc = _collection(uid).doc();
      await doc.set(
        Resume(id: doc.id, name: name, base64: base64, isActive: false, createdAt: now, updatedAt: now).toMap(),
      );
      return doc.id;
    } on FirebaseException {
      throw const NetworkFailure("Couldn't save your resume — check your internet and try again.");
    }
  }

  Future<void> rename({required String uid, required String resumeId, required String name}) async {
    try {
      await _collection(uid).doc(resumeId).update({'name': name, 'updatedAt': Timestamp.now()});
    } on FirebaseException {
      throw const NetworkFailure("Couldn't rename that resume — check your internet and try again.");
    }
  }

  /// Deletes one resume. If it was the active one, the caller is
  /// responsible for clearing `UserProfile.resumeBase64` separately (see
  /// `ResumeController.deleteResume`) — this method only touches the
  /// subcollection doc, not the profile.
  Future<void> delete({required String uid, required String resumeId}) async {
    try {
      await _collection(uid).doc(resumeId).delete();
    } on FirebaseException {
      throw const NetworkFailure("Couldn't remove that resume — check your internet and try again.");
    }
  }

  /// Marks [resumeId] active (clearing every other resume's flag) and
  /// mirrors its base64 onto the profile doc's `resumeBase64` field —
  /// see `Resume`'s doc comment for why that mirror exists at all.
  Future<void> setActive({required String uid, required String resumeId}) async {
    try {
      final snapshot = await _collection(uid).get();
      final batch = _firestore.batch();
      String? activeBase64;
      for (final doc in snapshot.docs) {
        final isTarget = doc.id == resumeId;
        if (isTarget) activeBase64 = doc.data()['base64'] as String?;
        // Skip a no-op write on docs that are already in the right state
        // — avoids bumping every other resume's Firestore write metadata
        // just because one sibling became active.
        final currentlyActive = doc.data()['isActive'] as bool? ?? false;
        if (currentlyActive != isTarget) {
          batch.update(doc.reference, {'isActive': isTarget});
        }
      }
      batch.update(_firestore.collection(FirestoreCollections.users).doc(uid), {
        'resumeBase64': activeBase64,
        'updatedAt': Timestamp.now(),
      });
      await batch.commit();
    } on FirebaseException {
      throw const NetworkFailure("Couldn't switch your active resume — check your internet and try again.");
    }
  }
}
