import 'package:equatable/equatable.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb_auth;

import '../../core/utils/firestore_codec.dart';
import 'work_experience_entry.dart';

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
    this.resumeBase64,
    this.photoBase64,
    this.workExperience = const [],
    this.onboardingComplete = false,
    required this.createdAt,
    required this.updatedAt,
  });

  /// Matches `firebase_auth`'s uid — also the Firestore document ID, so a
  /// profile is always fetched by direct `doc(uid)` lookup, never a query.
  final String uid;

  final String displayName;
  final String email;

  /// A name-like label for screens that shouldn't show a raw email
  /// address as if it were a name — [displayName] when the user (or
  /// their Google/email-password sign-in) actually has one, otherwise a
  /// friendly name derived from the email's own local part (e.g.
  /// "naafisa.medha@gmail.com" -> "Naafisa Medha") rather than the bare
  /// address itself.
  String get friendlyUsername {
    if (displayName.isNotEmpty) return displayName;
    final localPart = email.split('@').first;
    final words = localPart.split(RegExp(r'[._\-]+')).where((w) => w.isNotEmpty);
    if (words.isEmpty) return email;
    return words.map((w) => w[0].toUpperCase() + w.substring(1)).join(' ');
  }

  /// Short self-description shown on the profile screen (e.g. "Backend
  /// developer, 3 yrs, fintech"). Optional — not required to reach the feed.
  final String? headline;

  /// Free-text skills the user entered during onboarding. This is the set
  /// the match-gap LLM call diffs against a listing's `requiredSkills` to
  /// produce `MatchResult.matchedSkills` / `gapSkills`.
  final List<String> skills;

  final int? yearsOfExperience;
  final String? educationLevel;

  /// The uploaded resume PDF, base64-encoded, stored directly on this doc
  /// rather than a separate file store — see "Decision: resume storage,
  /// twice reconsidered" in docs/ARCHITECTURE.md: Firebase Storage and
  /// Cloudflare R2 both require a billing card on file even at $0 actual
  /// cost, which wasn't available, so the resume lives here instead.
  /// Keeps the whole doc under Firestore's 1MiB cap — see the upload
  /// size check in `resume_screen.dart`.
  final String? resumeBase64;

  /// A small JPEG thumbnail the user picked as their avatar, base64-encoded
  /// and stored directly on this doc — same reasoning and constraint as
  /// [resumeBase64] (no billing-free file store available), but resized/
  /// re-encoded client-side first (see `ProfilePhotoController`) so it
  /// stays tiny regardless of the original photo's size, instead of
  /// rejecting anything over a hard cap the way the resume upload does.
  final String? photoBase64;

  /// Work history pulled from the resume upload — see `WorkExperienceEntry`
  /// for why `duration` is free text. Wholesale-replaced on every resume
  /// sync (see `ResumeController`), not merged entry-by-entry: there's no
  /// manual "add experience" UI, so the resume is always the single source
  /// of truth for this list.
  final List<WorkExperienceEntry> workExperience;

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
      resumeBase64: map['resumeBase64'] as String?,
      photoBase64: map['photoBase64'] as String?,
      workExperience: (map['workExperience'] as List? ?? const [])
          .map((entry) => WorkExperienceEntry.fromMap(Map<String, dynamic>.from(entry as Map)))
          .toList(),
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
      'resumeBase64': resumeBase64,
      'photoBase64': photoBase64,
      'workExperience': workExperience.map((entry) => entry.toMap()).toList(),
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
    String? resumeBase64,
    String? photoBase64,
    List<WorkExperienceEntry>? workExperience,
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
      resumeBase64: resumeBase64 ?? this.resumeBase64,
      photoBase64: photoBase64 ?? this.photoBase64,
      workExperience: workExperience ?? this.workExperience,
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
        resumeBase64,
        photoBase64,
        workExperience,
        onboardingComplete,
        createdAt,
        updatedAt,
      ];
}
