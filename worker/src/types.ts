/**
 * Shapes mirrored from `lib/data/models/` (Dart). Kept minimal — only the
 * fields the Worker actually reads or writes — rather than a full 1:1 port.
 * There's no shared package between Dart and TypeScript here, so these two
 * definitions must be kept in sync by hand; see docs/DATA_MODELS.md for the
 * canonical field list.
 */

export interface JobListingDoc {
  title: string;
  company: string;
  companyDomain?: string;
  location: string;
  salaryMin?: number;
  salaryMax?: number;
  salaryCurrency: string;
  description: string;
  requiredSkills: string[];
  contactMethod: 'email' | 'phone' | 'whatsappOnly' | 'applicationPortal';
  applicationFeeRequired: boolean;
}

export interface UserProfileDoc {
  skills: string[];
  yearsOfExperience?: number;
  educationLevel?: string;
}

export interface ScamRuleFlags {
  upfrontFeesRequested: boolean;
  unrealisticSalary: boolean;
  noVerifiableDomain: boolean;
  urgencyLanguage: boolean;
  whatsappOnlyContact: boolean;
}

export type TrustBadge = 'verifiedLeaning' | 'caution' | 'highRisk';

/** Gemini's structured response for a match-gap call — parsed straight
 * into this shape, no prose wrapper (enforced via responseSchema). */
export interface MatchGeminiResult {
  matchPercent: number;
  matchedSkills: string[];
  gapSkills: string[];
  reasoning: string;
  upskillingRoadmap: string[];
}

/** Gemini's structured response for a scam-risk call. `trustBadge` is
 * still decided by the deterministic `ruleScore` (see scamRules.ts), not
 * by the LLM — this is only the plain-language explanation. */
export interface ScamGeminiResult {
  reasoning: string;
}
