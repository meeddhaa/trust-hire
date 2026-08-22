import 'package:equatable/equatable.dart';

import '../../core/utils/firestore_codec.dart';

/// Cached output of one explainable-match Gemini call for a (user, listing)
/// pair, stored at `matchResults/{userId}_{listingId}`.
///
/// Deliberately holds the *full* result — matched skills, gap skills,
/// reasoning, and roadmap — regardless of the viewing user's tier. Per
/// `docs/ARCHITECTURE.md`, free vs. paid gating happens in the UI layer
/// (free tier renders `matchPercent` only; paid tier renders all of it),
/// not by computing two different shapes. That keeps the Worker call and
/// the cache single-source, and means upgrading mid-session never needs a
/// re-fetch — the data was already there.
class MatchResult extends Equatable {
  const MatchResult({
    required this.id,
    required this.userId,
    required this.listingId,
    required this.matchPercent,
    this.matchedSkills = const [],
    this.gapSkills = const [],
    required this.reasoning,
    this.upskillingRoadmap = const [],
    required this.computedAt,
    required this.modelVersion,
  });

  /// `'${userId}_${listingId}'` — deterministic so a repeat lookup is a
  /// direct document read, never a query, and re-opening a listing can't
  /// accidentally create a second cached result for the same pair.
  final String id;

  final String userId;
  final String listingId;

  /// 0–100. The only field free-tier users see.
  final int matchPercent;

  /// Skills present in both the user's profile and the listing's
  /// `requiredSkills`. Paid-tier only in the UI.
  final List<String> matchedSkills;

  /// Skills the listing wants that the user's profile doesn't show.
  /// Paid-tier only in the UI.
  final List<String> gapSkills;

  /// Short plain-language explanation from Gemini, e.g. "Matched: Python,
  /// SQL. Gap: no cloud/AWS experience, no leadership project." Paid-tier
  /// only in the UI.
  final String reasoning;

  /// Personalized upskilling suggestions (paid-tier feature from the
  /// brief), e.g. ["Build a small AWS-hosted project", "Lead a team
  /// project, even a small one, to close the leadership gap"].
  final List<String> upskillingRoadmap;

  final DateTime computedAt;

  /// Which Gemini model/prompt version produced this, e.g.
  /// `"gemini-1.5-flash@match-v1"`. Lets us invalidate old cached results
  /// after a prompt change without a schema migration — the repository
  /// just treats a stale `modelVersion` as a cache miss.
  final String modelVersion;

  static String buildId({required String userId, required String listingId}) =>
      '${userId}_$listingId';

  factory MatchResult.fromMap(Map<String, dynamic> map, {required String id}) {
    return MatchResult(
      id: id,
      userId: map['userId'] as String? ?? '',
      listingId: map['listingId'] as String? ?? '',
      matchPercent: map['matchPercent'] as int? ?? 0,
      matchedSkills: List<String>.from(map['matchedSkills'] as List? ?? const []),
      gapSkills: List<String>.from(map['gapSkills'] as List? ?? const []),
      reasoning: map['reasoning'] as String? ?? '',
      upskillingRoadmap: List<String>.from(map['upskillingRoadmap'] as List? ?? const []),
      computedAt: dateTimeFromValue(map['computedAt']),
      modelVersion: map['modelVersion'] as String? ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'listingId': listingId,
      'matchPercent': matchPercent,
      'matchedSkills': matchedSkills,
      'gapSkills': gapSkills,
      'reasoning': reasoning,
      'upskillingRoadmap': upskillingRoadmap,
      'computedAt': timestampFromDateTime(computedAt),
      'modelVersion': modelVersion,
    };
  }

  @override
  List<Object?> get props => [
        id,
        userId,
        listingId,
        matchPercent,
        matchedSkills,
        gapSkills,
        reasoning,
        upskillingRoadmap,
        computedAt,
        modelVersion,
      ];
}
