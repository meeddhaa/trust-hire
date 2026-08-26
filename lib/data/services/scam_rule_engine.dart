import '../models/job_listing.dart';
import '../models/scam_assessment.dart';
import '../models/scam_rule_flags.dart';

/// Deterministic scam scorer — the five signals named in the brief,
/// computed instantly from a [JobListing] alone, no network call. Runs on
/// every feed card render so a preliminary trust badge shows on first
/// paint, before a listing is ever opened.
///
/// This is a Dart port of `worker/src/scamRules.ts`. The TypeScript copy
/// runs in the Cloudflare Worker to compute the *cached*, shared-across-
/// users `ScamAssessment` once per listing; this copy runs here for the
/// instant per-card preview. Same signals, same thresholds — kept in sync
/// by hand, since there's no shared package between Dart and TypeScript.
/// If you change a threshold or pattern in one, change it in the other.
class ScamRuleEngine {
  const ScamRuleEngine._();

  static const _freeMailDomains = {
    'gmail.com',
    'yahoo.com',
    'hotmail.com',
    'outlook.com',
    'live.com',
  };

  static final _urgencyPatterns = [
    RegExp(r'apply\s+immediately', caseSensitive: false),
    RegExp(r'urgent(ly)?\s+hir(e|ing)', caseSensitive: false),
    RegExp(r'limited\s+slots?', caseSensitive: false),
    RegExp(r'hurry', caseSensitive: false),
    RegExp(r'hiring\s+today', caseSensitive: false),
    RegExp(r'join\s+immediately', caseSensitive: false),
    RegExp(r'only\s+\d+\s+(seats?|slots?|vacanc(y|ies))\s+left', caseSensitive: false),
    RegExp(r'closing\s+soon', caseSensitive: false),
  ];

  static final _feePatterns = [
    RegExp(r'registration\s+fee', caseSensitive: false),
    RegExp(r'training\s+(fee|deposit)', caseSensitive: false),
    RegExp(r'refundable\s+deposit', caseSensitive: false),
    RegExp(r'processing\s+fee', caseSensitive: false),
    RegExp(r'security\s+(fee|deposit)', caseSensitive: false),
  ];

  /// BDT/month ceiling above which a listing needs real seniority signals
  /// (several required skills) to be plausible. Tuned for "too good to be
  /// true, no-experience-needed" postings, not senior roles that
  /// legitimately pay well.
  static const _implausibleSalaryBdt = 300000;
  static const _seniorSkillCountThreshold = 2;

  /// A large figure ($ or BDT-style) mentioned in free text — real gap
  /// found in production: JSearch-sourced listings never populate
  /// salaryMin/salaryMax, so a genuine "$100,000/year" sitting in a title
  /// was invisible to the structured check below. Matched only alongside
  /// explicit no-qualification-needed language, not on its own — a high
  /// figure alone is what plenty of legitimate senior/remote roles
  /// advertise; "huge pay + no real qualification needed" is the actual
  /// pattern, not the pay by itself.
  static final _largeFigurePatterns = [
    RegExp(r'\$[\d,]{5,}'),
    RegExp(r'(?:bdt|taka)\s?[\d,]{6,}', caseSensitive: false),
    RegExp(r'[\d,]{6,}\s?(?:bdt|taka)', caseSensitive: false),
  ];
  static final _noQualificationPatterns = [
    RegExp(r'no\s+experience\s+(needed|required)', caseSensitive: false),
    RegExp(r'entry[\s-]level', caseSensitive: false),
    RegExp(r'fresher', caseSensitive: false),
    RegExp(r'anyone\s+can\s+apply', caseSensitive: false),
    RegExp(r'no\s+skills?\s+required', caseSensitive: false),
  ];

  static ScamRuleFlags computeFlags(JobListing listing) {
    final domain = listing.companyDomain?.toLowerCase().trim();
    final combinedText = '${listing.title} ${listing.description}';

    final salaryMax = listing.salaryMax;
    final salaryMin = listing.salaryMin;
    final structuredSalaryUnrealistic = salaryMax != null &&
        ((salaryMin != null && salaryMin > salaryMax) ||
            (salaryMax > _implausibleSalaryBdt &&
                listing.requiredSkills.length < _seniorSkillCountThreshold));

    // Only a fallback for listings with no structured salary at all —
    // avoids disagreeing with the structured check when one exists.
    final textSalaryUnrealistic = salaryMax == null &&
        _largeFigurePatterns.any((p) => p.hasMatch(combinedText)) &&
        _noQualificationPatterns.any((p) => p.hasMatch(combinedText));

    final unrealisticSalary = structuredSalaryUnrealistic || textSalaryUnrealistic;

    return ScamRuleFlags(
      upfrontFeesRequested: listing.applicationFeeRequired ||
          _feePatterns.any((p) => p.hasMatch(listing.description)),
      unrealisticSalary: unrealisticSalary,
      noVerifiableDomain: domain == null || domain.isEmpty || _freeMailDomains.contains(domain),
      urgencyLanguage: _urgencyPatterns.any((p) => p.hasMatch(listing.description)),
      whatsappOnlyContact: listing.contactMethod == ContactMethod.whatsappOnly,
    );
  }

  /// 0–100, in steps of 20 across the five signals.
  static int computeRuleScore(ScamRuleFlags flags) => flags.triggeredCount * 20;

  /// 0 flags → verified-leaning, 1 → caution, 2+ → high risk. One or two
  /// red flags on a job listing is already enough to warrant real
  /// caution, so the banding is intentionally strict rather than
  /// proportional to the full 0–100 range.
  static TrustBadge bandTrustBadge(int ruleScore) {
    if (ruleScore == 0) return TrustBadge.verifiedLeaning;
    if (ruleScore <= 20) return TrustBadge.caution;
    return TrustBadge.highRisk;
  }

  /// Convenience for the feed card: flags + score + badge in one call,
  /// without the LLM reasoning (that only gets fetched on listing open —
  /// see `ScamRepository`, step 4).
  static ({ScamRuleFlags flags, int ruleScore, TrustBadge trustBadge}) assess(
    JobListing listing,
  ) {
    final flags = computeFlags(listing);
    final ruleScore = computeRuleScore(flags);
    return (flags: flags, ruleScore: ruleScore, trustBadge: bandTrustBadge(ruleScore));
  }
}
