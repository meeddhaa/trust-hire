import 'package:equatable/equatable.dart';

/// Gemini's resume-tailoring output for one (resume, listing) pair.
/// Unlike [MatchResult]/[ScamAssessment], this is never cached to
/// Firestore — a resume can change anytime, and it's a lower-traffic,
/// always-fresh-on-request feature (see `worker/src/index.ts`'s
/// `handleResumeTailor`), so there's no `fromMap`/Firestore round trip to
/// worry about, just parsing the Worker's JSON response directly.
class ResumeTailorResult extends Equatable {
  const ResumeTailorResult({
    required this.listingId,
    required this.tailoredSummary,
    required this.emphasize,
    required this.addKeywords,
    required this.suggestions,
  });

  final String listingId;

  /// A resume summary/objective rewritten toward this specific listing.
  final String tailoredSummary;

  /// Things already in the resume worth foregrounding for this role.
  final List<String> emphasize;

  /// Terms from the listing the resume's real experience supports but
  /// doesn't currently use.
  final List<String> addKeywords;

  /// Concrete edits, not generic advice.
  final List<String> suggestions;

  factory ResumeTailorResult.fromJson(Map<String, dynamic> json) {
    return ResumeTailorResult(
      listingId: json['listingId'] as String,
      tailoredSummary: json['tailoredSummary'] as String? ?? '',
      emphasize: List<String>.from(json['emphasize'] as List? ?? const []),
      addKeywords: List<String>.from(json['addKeywords'] as List? ?? const []),
      suggestions: List<String>.from(json['suggestions'] as List? ?? const []),
    );
  }

  @override
  List<Object?> get props => [listingId, tailoredSummary, emphasize, addKeywords, suggestions];
}
