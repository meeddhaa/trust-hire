import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb_auth;
import '../../core/constants/firestore_collections.dart';
import '../../core/errors/failure.dart';
import '../../core/utils/bd_phone.dart';
import '../models/user_profile.dart';
import '../models/work_experience_entry.dart';

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
  /// or the listings feed. `displayName` is collected here rather than
  /// pulled off the Firebase user (see `UserProfile.fromFirebaseUser`)
  /// because a phone+OTP sign-in has no such thing — this is the one
  /// point every user, regardless of how they signed in, passes through,
  /// so it's what guarantees `friendlyUsername` never falls all the way
  /// back to a bare phone number or "there".
  Future<void> saveOnboarding({
    required String uid,
    required String displayName,
    required List<String> skills,
    int? yearsOfExperience,
    String? educationLevel,
    String? headline,
  }) async {
    try {
      await _doc(uid).update({
        'displayName': displayName,
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

  /// Saves (or, with `null`, clears) the base64-encoded resume PDF
  /// directly on the profile doc — see "Decision: resume storage, twice
  /// reconsidered" in docs/ARCHITECTURE.md for why there's no separate
  /// file store involved.
  Future<void> setResumeBase64(String uid, String? base64) async {
    try {
      await _doc(uid).update({'resumeBase64': base64, 'updatedAt': Timestamp.now()});
    } on FirebaseException {
      throw const NetworkFailure("Couldn't save your resume — check your internet and try again.");
    }
  }

  /// Updates the display name after onboarding (see `SettingsScreen`) —
  /// onboarding itself only ever runs once per account, so anyone who
  /// completed it before that screen collected a name needs this to fix
  /// `UserProfile.friendlyUsername` falling back to their phone number.
  Future<void> setDisplayName(String uid, String name) async {
    try {
      await _doc(uid).update({'displayName': name, 'updatedAt': Timestamp.now()});
    } on FirebaseException {
      throw const NetworkFailure("Couldn't save your name — check your internet and try again.");
    }
  }

  /// Saves the user's phone number, normalized via [normalizeBdPhoneNumber]
  /// first — see `UserProfile.phoneNumber`'s doc comment for why the exact
  /// normalized form matters (it's the field the AppsPro webhook queries
  /// by an exact match, see `worker/src/appspro.ts`).
  Future<void> setPhoneNumber(String uid, String rawPhone) async {
    try {
      await _doc(uid).update({
        'phoneNumber': normalizeBdPhoneNumber(rawPhone),
        'updatedAt': Timestamp.now(),
      });
    } on FirebaseException {
      throw const NetworkFailure("Couldn't save your phone number — check your internet and try again.");
    }
  }

  /// Saves (or, with `null`, clears) the base64-encoded avatar thumbnail —
  /// same field-on-the-profile-doc approach as [setResumeBase64], but the
  /// image is already resized/re-encoded small by `ProfilePhotoController`
  /// before it ever reaches here.
  Future<void> setPhotoBase64(String uid, String? base64) async {
    try {
      await _doc(uid).update({'photoBase64': base64, 'updatedAt': Timestamp.now()});
    } on FirebaseException {
      throw const NetworkFailure("Couldn't save your photo — check your internet and try again.");
    }
  }

  /// Replaces the profile's work-experience list wholesale — see
  /// `UserProfile.workExperience`'s doc comment for why this is a
  /// replace, not a merge (there's no manual "add experience" entry
  /// point, only the resume sync, so the resume is always authoritative).
  Future<void> setWorkExperience(String uid, List<WorkExperienceEntry> experience) async {
    try {
      await _doc(uid).update({
        'workExperience': experience.map((entry) => entry.toMap()).toList(),
        'updatedAt': Timestamp.now(),
      });
    } on FirebaseException {
      throw const NetworkFailure("Couldn't save your work experience — check your internet and try again.");
    }
  }

  /// Adds [newSkills] to the profile's existing skill list, case-insensitive
  /// deduped against what's already there — used right after a resume
  /// upload (see `ResumeController.uploadResume`) to fold in whatever the
  /// Gemini extraction call found. Returns the skills actually added (a
  /// subset of [newSkills], with duplicates removed) so the caller can
  /// tell the user something concrete ("added 4 skills"), not just "done."
  Future<List<String>> addSkills(String uid, List<String> newSkills) async {
    try {
      final snapshot = await _doc(uid).get();
      final existing = List<String>.from(snapshot.data()?['skills'] as List? ?? const []);
      final existingLower = existing.map((s) => s.toLowerCase()).toSet();

      final toAdd = <String>[];
      for (final skill in newSkills) {
        if (existingLower.add(skill.toLowerCase())) toAdd.add(skill);
      }
      if (toAdd.isEmpty) return const [];

      await _doc(uid).update({
        'skills': [...existing, ...toAdd],
        'updatedAt': Timestamp.now(),
      });
      return toAdd;
    } on FirebaseException {
      throw const NetworkFailure("Couldn't update your skills — check your internet and try again.");
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
