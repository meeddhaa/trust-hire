import type { GeminiJsonSchema } from './gemini';
import type { JobListingDoc, ScamRuleFlags, UserProfileDoc } from './types';

/**
 * Prompt + schema pairs for the two AI features. Kept deliberately narrow
 * — each schema has exactly the fields the corresponding UI model needs,
 * so there's no prose to strip and no risk of the model wandering off the
 * shape (this is the bonus-marks requirement: the LLM output has to
 * materially change what the user sees, not decorate a static summary).
 */

export const MATCH_RESPONSE_SCHEMA: GeminiJsonSchema = {
  type: 'OBJECT',
  properties: {
    matchPercent: { type: 'INTEGER' },
    matchedSkills: { type: 'ARRAY', items: { type: 'STRING' } },
    gapSkills: { type: 'ARRAY', items: { type: 'STRING' } },
    reasoning: { type: 'STRING' },
    upskillingRoadmap: { type: 'ARRAY', items: { type: 'STRING' } },
  },
  required: ['matchPercent', 'matchedSkills', 'gapSkills', 'reasoning', 'upskillingRoadmap'],
};

export const SCAM_RESPONSE_SCHEMA: GeminiJsonSchema = {
  type: 'OBJECT',
  properties: {
    reasoning: { type: 'STRING' },
  },
  required: ['reasoning'],
};

const MATCH_SYSTEM_INSTRUCTION = `You are the explainable job-matching engine inside TrustHire, an app \
helping job seekers in Bangladesh evaluate listings. Given a candidate's \
profile and a job listing, you must:
1. Compute matchPercent (0-100): how well the candidate's skills and \
experience fit the listing's stated requirements.
2. List matchedSkills: skills the candidate has that the listing asks for.
3. List gapSkills: skills or experience the listing asks for that the \
candidate's profile doesn't show.
4. Write reasoning: ONE short sentence in the exact style "Matched: X, Y. \
Gap: <specific missing thing>, <specific missing thing>." — concrete, not \
generic filler like "good fit" or "some experience needed."
5. Write upskillingRoadmap: 2-4 short, specific, actionable steps that \
would close the listed gaps (not generic advice like "learn more").
Ground every field in the given profile and listing text only — do not \
invent skills, requirements, or experience that weren't provided. Respond \
with JSON only, matching the schema exactly, no text outside the JSON.`;

const SCAM_SYSTEM_INSTRUCTION = `You are the scam-risk explainer inside TrustHire, an app helping job \
seekers in Bangladesh spot fraudulent listings. You are given a job \
listing's text and a set of deterministic rule flags that have ALREADY \
been decided by a separate rule engine (do not re-decide or contradict \
them). Your only job is to write reasoning: a short, plain-language, \
1-3 sentence explanation of why this listing is risky (or why it looks \
fine, if no flags fired), pointing to the SPECIFIC phrase, term, or \
detail in the listing text that supports each flag that fired. Do not \
invent risk signals beyond the flags given. If no flags fired, say so \
plainly and note what makes the listing look legitimate (verifiable \
domain, disclosed salary in a normal range, no pressure language). \
Respond with JSON only, matching the schema exactly, no text outside \
the JSON.`;

export function buildMatchPrompt(profile: UserProfileDoc, listing: JobListingDoc) {
  const userPrompt = JSON.stringify({
    candidate: {
      skills: profile.skills,
      yearsOfExperience: profile.yearsOfExperience ?? null,
      educationLevel: profile.educationLevel ?? null,
    },
    listing: {
      title: listing.title,
      company: listing.company,
      requiredSkills: listing.requiredSkills,
      description: listing.description,
    },
  });
  return { systemInstruction: MATCH_SYSTEM_INSTRUCTION, userPrompt };
}

export function buildScamPrompt(listing: JobListingDoc, flags: ScamRuleFlags) {
  const userPrompt = JSON.stringify({
    listing: {
      title: listing.title,
      company: listing.company,
      companyDomain: listing.companyDomain ?? null,
      salaryMin: listing.salaryMin ?? null,
      salaryMax: listing.salaryMax ?? null,
      salaryCurrency: listing.salaryCurrency,
      contactMethod: listing.contactMethod,
      description: listing.description,
    },
    ruleFlagsAlreadyDecided: flags,
  });
  return { systemInstruction: SCAM_SYSTEM_INSTRUCTION, userPrompt };
}
