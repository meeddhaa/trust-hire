import 'package:equatable/equatable.dart';

/// The five deterministic scam signals named in the brief. Computed
/// instantly, client-side, by `data/services/scam_rule_engine.dart` from a
/// [JobListing] alone — no network call, so every card in the feed can show
/// a preliminary trust badge on first paint without burning LLM quota.
///
/// This same shape is also what gets embedded in a cached [ScamAssessment]
/// once the Worker's LLM call resolves, so the rule engine's output and the
/// stored record never disagree about which signals fired.
class ScamRuleFlags extends Equatable {
  const ScamRuleFlags({
    this.upfrontFeesRequested = false,
    this.unrealisticSalary = false,
    this.noVerifiableDomain = false,
    this.urgencyLanguage = false,
    this.whatsappOnlyContact = false,
  });

  /// Listing asks the applicant to pay something before being hired.
  final bool upfrontFeesRequested;

  /// Disclosed salary is implausible for the role/location/experience
  /// level (rule engine compares against a rough band, not an LLM guess).
  final bool unrealisticSalary;

  /// No company domain on file, or the domain is a free-mail provider
  /// (gmail.com, yahoo.com, ...) rather than a company-owned one.
  final bool noVerifiableDomain;

  /// Listing text uses pressure language ("apply immediately", "only 2
  /// slots left", "hiring today") — matched against a keyword/pattern set,
  /// not sentiment analysis.
  final bool urgencyLanguage;

  /// Only a WhatsApp number is given, with no email, phone line, or
  /// application portal.
  final bool whatsappOnlyContact;

  /// How many of the five signals fired. Feeds directly into the
  /// deterministic 0–100 rule score (see `scam_rule_engine.dart`) and is
  /// handy on its own for a quick "N of 5 warning signs" UI treatment.
  int get triggeredCount => [
        upfrontFeesRequested,
        unrealisticSalary,
        noVerifiableDomain,
        urgencyLanguage,
        whatsappOnlyContact,
      ].where((flag) => flag).length;

  factory ScamRuleFlags.fromMap(Map<String, dynamic> map) {
    return ScamRuleFlags(
      upfrontFeesRequested: map['upfrontFeesRequested'] as bool? ?? false,
      unrealisticSalary: map['unrealisticSalary'] as bool? ?? false,
      noVerifiableDomain: map['noVerifiableDomain'] as bool? ?? false,
      urgencyLanguage: map['urgencyLanguage'] as bool? ?? false,
      whatsappOnlyContact: map['whatsappOnlyContact'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'upfrontFeesRequested': upfrontFeesRequested,
      'unrealisticSalary': unrealisticSalary,
      'noVerifiableDomain': noVerifiableDomain,
      'urgencyLanguage': urgencyLanguage,
      'whatsappOnlyContact': whatsappOnlyContact,
    };
  }

  @override
  List<Object?> get props => [
        upfrontFeesRequested,
        unrealisticSalary,
        noVerifiableDomain,
        urgencyLanguage,
        whatsappOnlyContact,
      ];
}
