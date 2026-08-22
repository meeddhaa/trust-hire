import 'package:equatable/equatable.dart';

import '../../core/utils/firestore_codec.dart';
import 'scam_rule_flags.dart';

/// The three-way verdict shown as the trust badge on every listing card.
/// Both tiers see this — it's the free-tier scam-detection surface named in
/// the brief, distinct from the full reasoning text which is paid-only.
enum TrustBadge {
  verifiedLeaning,
  caution,
  highRisk;

  static TrustBadge fromString(String value) => TrustBadge.values.firstWhere(
        (v) => v.name == value,
        orElse: () => TrustBadge.caution,
      );
}

/// Cached output of one scam-risk assessment for a listing, stored at
/// `scamAssessments/{listingId}`.
///
/// Not user-scoped — unlike [MatchResult], a listing's fraud risk doesn't
/// depend on who's looking at it, so one document serves every user and
/// the Worker's Gemini call for a given listing only ever runs once.
class ScamAssessment extends Equatable {
  const ScamAssessment({
    required this.listingId,
    required this.ruleFlags,
    required this.ruleScore,
    required this.trustBadge,
    required this.reasoning,
    required this.computedAt,
    required this.modelVersion,
  });

  final String listingId;

  /// The deterministic signals that fed the rule score — kept alongside
  /// the LLM reasoning so the UI can show "here's what tripped the flag"
  /// even before/without rendering the prose explanation.
  final ScamRuleFlags ruleFlags;

  /// 0–100 deterministic score from the rule engine (see
  /// `data/services/scam_rule_engine.dart`), computed *before* and
  /// independently of the LLM call — per the brief, this must never cost
  /// API quota. `trustBadge` is a banding of this score.
  final int ruleScore;

  final TrustBadge trustBadge;

  /// Plain-language explanation from Gemini, grounded in `ruleFlags` and
  /// the listing text (e.g. "Asks for a refundable training fee and lists
  /// no company domain — treat as high risk."). Free tier sees only
  /// `trustBadge`; paid tier sees this too.
  final String reasoning;

  final DateTime computedAt;

  /// Same purpose as `MatchResult.modelVersion` — lets a prompt change
  /// invalidate old cached assessments without a schema migration.
  final String modelVersion;

  factory ScamAssessment.fromMap(Map<String, dynamic> map, {required String listingId}) {
    return ScamAssessment(
      listingId: listingId,
      ruleFlags: ScamRuleFlags.fromMap(
        Map<String, dynamic>.from(map['ruleFlags'] as Map? ?? const {}),
      ),
      ruleScore: map['ruleScore'] as int? ?? 0,
      trustBadge: TrustBadge.fromString(map['trustBadge'] as String? ?? ''),
      reasoning: map['reasoning'] as String? ?? '',
      computedAt: dateTimeFromValue(map['computedAt']),
      modelVersion: map['modelVersion'] as String? ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'ruleFlags': ruleFlags.toMap(),
      'ruleScore': ruleScore,
      'trustBadge': trustBadge.name,
      'reasoning': reasoning,
      'computedAt': timestampFromDateTime(computedAt),
      'modelVersion': modelVersion,
    };
  }

  @override
  List<Object?> get props => [
        listingId,
        ruleFlags,
        ruleScore,
        trustBadge,
        reasoning,
        computedAt,
        modelVersion,
      ];
}
