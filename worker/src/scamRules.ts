import type { JobListingDoc, ScamRuleFlags, TrustBadge } from './types';

/**
 * Deterministic scam scorer — the five signals named in the brief.
 *
 * This is a TypeScript port of `lib/data/services/scam_rule_engine.dart`.
 * The Dart copy runs client-side for the instant per-card badge (no
 * network call, per the brief); this copy runs here so the *cached*
 * `scamAssessments/{listingId}` — shared by every user — is computed once,
 * server-side, from the listing data alone, and can't drift from client to
 * client depending on who happened to open the listing first. Same
 * signals, same thresholds, kept in sync by hand — see the doc comment in
 * the Dart file.
 */

const FREE_MAIL_DOMAINS = new Set([
  'gmail.com',
  'yahoo.com',
  'hotmail.com',
  'outlook.com',
  'live.com',
]);

const URGENCY_PATTERNS = [
  /apply\s+immediately/i,
  /urgent(ly)?\s+hir(e|ing)/i,
  /limited\s+slots?/i,
  /hurry/i,
  /hiring\s+today/i,
  /join\s+immediately/i,
  /only\s+\d+\s+(seats?|slots?|vacanc(y|ies))\s+left/i,
  /closing\s+soon/i,
];

const FEE_PATTERNS = [
  /registration\s+fee/i,
  /training\s+(fee|deposit)/i,
  /refundable\s+deposit/i,
  /processing\s+fee/i,
  /security\s+(fee|deposit)/i,
];

/** BDT/month ceiling above which a listing needs real seniority signals
 * (several required skills) to be plausible. Tuned for "too good to be
 * true, no-experience-needed" postings, not senior roles that legitimately
 * pay well. */
const IMPLAUSIBLE_SALARY_BDT = 300_000;
const SENIOR_SKILL_COUNT_THRESHOLD = 2;

/** A large figure ($ or BDT-style) mentioned in free text — title or
 * description — for listings that don't disclose salary in the
 * structured fields at all (real gap found in production: JSearch never
 * populates salaryMin/salaryMax, so a genuine "$100,000/year" in a title
 * was invisible to the check above). Matched only in combination with
 * explicit no-qualification-needed language below, not on its own — a
 * high figure alone is what plenty of legitimate senior/remote roles
 * advertise; it's "huge pay + no real qualification needed" that's the
 * actual scam pattern, not the pay by itself. */
const LARGE_FIGURE_PATTERNS = [/\$[\d,]{5,}/, /(?:bdt|taka)\s?[\d,]{6,}/i, /[\d,]{6,}\s?(?:bdt|taka)/i];
const NO_QUALIFICATION_PATTERNS = [
  /no\s+experience\s+(needed|required)/i,
  /entry[\s-]level/i,
  /fresher/i,
  /anyone\s+can\s+apply/i,
  /no\s+skills?\s+required/i,
];

export function computeScamRuleFlags(listing: JobListingDoc): ScamRuleFlags {
  const domain = listing.companyDomain?.toLowerCase().trim();
  const combinedText = `${listing.title} ${listing.description}`;

  const structuredSalaryUnrealistic =
    listing.salaryMax !== undefined &&
    ((listing.salaryMin !== undefined && listing.salaryMin > listing.salaryMax) ||
      (listing.salaryMax > IMPLAUSIBLE_SALARY_BDT &&
        listing.requiredSkills.length < SENIOR_SKILL_COUNT_THRESHOLD));

  // Only a fallback for listings with no structured salary at all — if
  // salaryMax is already set, the check above already covers it, and we
  // don't want the two checks to disagree with each other.
  const textSalaryUnrealistic =
    listing.salaryMax === undefined &&
    LARGE_FIGURE_PATTERNS.some((p) => p.test(combinedText)) &&
    NO_QUALIFICATION_PATTERNS.some((p) => p.test(combinedText));

  const unrealisticSalary = structuredSalaryUnrealistic || textSalaryUnrealistic;

  return {
    upfrontFeesRequested:
      listing.applicationFeeRequired || FEE_PATTERNS.some((p) => p.test(listing.description)),
    unrealisticSalary,
    noVerifiableDomain: !domain || FREE_MAIL_DOMAINS.has(domain),
    urgencyLanguage: URGENCY_PATTERNS.some((p) => p.test(listing.description)),
    whatsappOnlyContact: listing.contactMethod === 'whatsappOnly',
  };
}

export function triggeredCount(flags: ScamRuleFlags): number {
  return Object.values(flags).filter(Boolean).length;
}

/** 0–100, in steps of 20 across the five signals. */
export function computeRuleScore(flags: ScamRuleFlags): number {
  return triggeredCount(flags) * 20;
}

/** 0 flags → verified-leaning, 1 → caution, 2+ → high risk. One or two
 * red flags on a job listing (not e.g. a loyalty program) is already
 * enough to warrant real caution, so the banding is intentionally strict
 * rather than proportional. */
export function bandTrustBadge(ruleScore: number): TrustBadge {
  if (ruleScore === 0) return 'verifiedLeaning';
  if (ruleScore <= 20) return 'caution';
  return 'highRisk';
}
