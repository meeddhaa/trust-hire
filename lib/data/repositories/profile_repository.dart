import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb_auth;
import '../../core/constants/firestore_collections.dart';
import '../../core/errors/failure.dart';
import '../models/user_profile.dart';

/// Reads/writes `users/{uid}` — the only collection the client is allowed
/// to write directly (see `firestore.rules`: owner-only read/write).
class ProfileRepository {
  ProfileRepository({FirebaseFirestore? firestore}) : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  DocumentReference<Map<String, dynamic>> _doc(String uid) =>
      _firestore.collection(FirestoreCollections.users).doc(uid);

  /// Live profile updates — used by the router's onboarding guard and by
  /// the profile screen, so both react instantly if either edits it.
  Stream<UserProfile?> watchProfile(String uid) {
    return _doc(uid).snapshots().map((snapshot) {
      final data = snapshot.data();
      if (data == null) return null;
      return UserProfile.fromMap(data, uid: uid);
    });
  }

  /// Creates the initial `users/{uid}` doc right after sign-up, before
  /// onboarding has collected anything — see `UserProfile.fromFirebaseUser`
  /// for the "new user" default shape. A no-op if the doc already exists
  /// (e.g. a returning user signing back in), so this is safe to call on
  /// every sign-in without checking first.
  Future<void> ensureProfileExists(fb_auth.User firebaseUser) async {
    final ref = _doc(firebaseUser.uid);
    try {
      final snapshot = await ref.get();
      if (snapshot.exists) return;
      await ref.set(UserProfile.fromFirebaseUser(firebaseUser).toMap());
    } on FirebaseException {
      throw const NetworkFailure("Couldn't set up your profile — check your internet and try again.");
    }
  }

  /// Saves the onboarding form and marks it complete — the router redirect
  /// guard checks `onboardingComplete` to decide whether to show onboarding
  /// or the listings feed.
  Future<void> saveOnboarding({
    required String uid,
    required List<String> skills,
    int? yearsOfExperience,
    String? educationLevel,
    String? headline,
  }) async {
    try {
      await _doc(uid).update({
        'skills': skills,
        'yearsOfExperience': yearsOfExperience,
        'educationLevel': educationLevel,
        'headline': headline,
        'onboardingComplete': true,
        'updatedAt': Timestamp.now(),
      });
    } on FirebaseException {
      throw const NetworkFailure("Couldn't save your profile — check your internet and try again.");
    }
  }

  /// Records where the resume landed in Storage (or `null` to clear it
  /// after a delete) — `ResumeService` handles the actual file, this just
  /// keeps the profile doc's pointer to it in sync.
  Future<void> setResumeStoragePath(String uid, String? path) async {
    try {
      await _doc(uid).update({'resumeStoragePath': path, 'updatedAt': Timestamp.now()});
    } on FirebaseException {
      throw const NetworkFailure("Couldn't save your resume info — check your internet and try again.");
    }
  }

  /// Used by account deletion — removes the `users/{uid}` doc itself.
  /// Called after applications/saved jobs/resume are already cleaned up
  /// (see `AccountController.deleteAccount`), and before the Auth account
  /// is deleted (needs to still be signed in to pass `isOwner(uid)`).
  Future<void> deleteProfile(String uid) async {
    try {
      await _doc(uid).delete();
    } on FirebaseException {
      throw const NetworkFailure("Couldn't delete your profile — check your internet and try again.");
    }
  }
}
