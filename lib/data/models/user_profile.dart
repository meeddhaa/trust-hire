import 'package:equatable/equatable.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb_auth;

import '../../core/utils/firestore_codec.dart';

/// A user's profile as stored in `users/{uid}`: the input to the match-gap
/// LLM call (skills, experience) plus onboarding/auth bookkeeping.
///
/// Named `UserProfile`, not `User`, to avoid colliding with
/// `firebase_auth`'s `User` — the two are imported side by side wherever
/// auth state and the Firestore profile are both in scope (e.g. onboarding).
class UserProfile extends Equatable {
  const UserProfile({
    required this.uid,
    required this.displayName,
    required this.email,
    this.headline,
    this.skills = const [],
    this.yearsOfExperience,
    this.educationLevel,
    this.resumeStoragePath,
    this.onboardingComplete = false,
    required this.createdAt,
    required this.updatedAt,
  });

  /// Matches `firebase_auth`'s uid — also the Firestore document ID, so a
  /// profile is always fetched by direct `doc(uid)` lookup, never a query.
  final String uid;

  final String displayName;
  final String email;

  /// Short self-description shown on the profile screen (e.g. "Backend
  /// developer, 3 yrs, fintech"). Optional — not required to reach the feed.
  final String? headline;

  /// Free-text skills the user entered during onboarding. This is the set
  /// the match-gap LLM call diffs against a listing's `requiredSkills` to
  /// produce `MatchResult.matchedSkills` / `gapSkills`.
  final List<String> skills;

  final int? yearsOfExperience;
  final String? educationLevel;

  /// Firebase Storage path (not a download URL — those expire) to the
  /// uploaded CV, e.g. `resumes/{uid}/cv.pdf`. Resolved to a URL on demand
  /// by whichever repository needs to render or attach it.
  final String? resumeStoragePath;

  /// Gates the onboarding → feed redirect in the router. False until the
  /// user has entered at least skills once.
  final bool onboardingComplete;

  final DateTime createdAt;
  final DateTime updatedAt;

  /// Builds the initial profile right after sign-up, before onboarding has
  /// collected anything else. Keeps that "new user" shape defined in one
  /// place instead of re-listing every default at each call site.
  factory UserProfile.fromFirebaseUser(fb_auth.User user) {
    final now = DateTime.now();
    return UserProfile(
      uid: user.uid,
      displayName: user.displayName ?? '',
      email: user.email ?? '',
      createdAt: now,
      updatedAt: now,
    );
  }

  factory UserProfile.fromMap(Map<String, dynamic> map, {required String uid}) {
    return UserProfile(
      uid: uid,
      displayName: map['displayName'] as String? ?? '',
      email: map['email'] as String? ?? '',
      headline: map['headline'] as String?,
      skills: List<String>.from(map['skills'] as List? ?? const []),
      yearsOfExperience: map['yearsOfExperience'] as int?,
      educationLevel: map['educationLevel'] as String?,
      resumeStoragePath: map['resumeStoragePath'] as String?,
      onboardingComplete: map['onboardingComplete'] as bool? ?? false,
      createdAt: dateTimeFromValue(map['createdAt']),
      updatedAt: dateTimeFromValue(map['updatedAt']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'displayName': displayName,
      'email': email,
      'headline': headline,
      'skills': skills,
      'yearsOfExperience': yearsOfExperience,
      'educationLevel': educationLevel,
      'resumeStoragePath': resumeStoragePath,
      'onboardingComplete': onboardingComplete,
      'createdAt': timestampFromDateTime(createdAt),
      'updatedAt': timestampFromDateTime(updatedAt),
    };
  }

  UserProfile copyWith({
    String? displayName,
    String? headline,
    List<String>? skills,
    int? yearsOfExperience,
    String? educationLevel,
    String? resumeStoragePath,
    bool? onboardingComplete,
    DateTime? updatedAt,
  }) {
    return UserProfile(
      uid: uid,
      displayName: displayName ?? this.displayName,
      email: email,
      headline: headline ?? this.headline,
      skills: skills ?? this.skills,
      yearsOfExperience: yearsOfExperience ?? this.yearsOfExperience,
      educationLevel: educationLevel ?? this.educationLevel,
      resumeStoragePath: resumeStoragePath ?? this.resumeStoragePath,
      onboardingComplete: onboardingComplete ?? this.onboardingComplete,
      createdAt: createdAt,
      updatedAt: updatedAt ?? DateTime.now(),
    );
  }

  @override
  List<Object?> get props => [
        uid,
        displayName,
        email,
        headline,
        skills,
        yearsOfExperience,
        educationLevel,
        resumeStoragePath,
        onboardingComplete,
        createdAt,
        updatedAt,
      ];
}
