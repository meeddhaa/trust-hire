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

export const RESUME_TAILOR_RESPONSE_SCHEMA: GeminiJsonSchema = {
  type: 'OBJECT',
  properties: {
    tailoredSummary: { type: 'STRING' },
    emphasize: { type: 'ARRAY', items: { type: 'STRING' } },
    addKeywords: { type: 'ARRAY', items: { type: 'STRING' } },
    suggestions: { type: 'ARRAY', items: { type: 'STRING' } },
  },
  required: ['tailoredSummary', 'emphasize', 'addKeywords', 'suggestions'],
};

export const JOB_COACH_RESPONSE_SCHEMA: GeminiJsonSchema = {
  type: 'OBJECT',
  properties: {
    answer: { type: 'STRING' },
    followUpSuggestions: { type: 'ARRAY', items: { type: 'STRING' } },
  },
  required: ['answer', 'followUpSuggestions'],
};

export const RESUME_SKILLS_RESPONSE_SCHEMA: GeminiJsonSchema = {
  type: 'OBJECT',
  properties: {
    skills: { type: 'ARRAY', items: { type: 'STRING' } },
  },
  required: ['skills'],
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

const RESUME_TAILOR_SYSTEM_INSTRUCTION = `You are the resume-tailoring assistant inside TrustHire, an app helping \
job seekers in Bangladesh apply well. You are given a candidate's actual \
resume (as an attached document) and one specific job listing. Using ONLY \
what the resume actually contains — never invent skills, employers, \
titles, dates, or achievements the resume doesn't support — produce:
1. tailoredSummary: a 2-3 sentence resume summary/objective rewritten to \
foreground the parts of THIS candidate's real background that matter \
most for THIS listing.
2. emphasize: 2-5 specific things already in the resume (a project, a \
skill, a past responsibility) the candidate should foreground or expand \
on for this application — quote or closely paraphrase the resume, don't \
generalize.
3. addKeywords: 2-6 terms from the listing's own required skills/language \
that are missing from the resume's wording but that the candidate's real \
experience plausibly supports using different words — only suggest a \
keyword if the resume shows the underlying substance, not just because \
the listing mentions it.
4. suggestions: 2-4 concrete edits (not generic advice like "tailor your \
resume") — e.g. "Move your Firebase project above your internship, since \
this role is backend-focused."
If the resume clearly doesn't support the role at all, say so plainly in \
suggestions rather than fabricating a fit. Respond with JSON only, \
matching the schema exactly, no text outside the JSON.`;

export function buildResumeTailorPrompt(listing: JobListingDoc) {
  const userPrompt = JSON.stringify({
    listing: {
      title: listing.title,
      company: listing.company,
      requiredSkills: listing.requiredSkills,
      description: listing.description,
    },
  });
  return { systemInstruction: RESUME_TAILOR_SYSTEM_INSTRUCTION, userPrompt };
}

const RESUME_SKILLS_SYSTEM_INSTRUCTION = `You extract skills from a resume for TrustHire, an app helping job \
seekers in Bangladesh. You are given a candidate's resume as an attached \
document, and optionally a list of skills they've already typed into \
their profile. Extract a concise list of concrete skills (technologies, \
tools, languages, frameworks, and named competencies) the resume gives \
clear EVIDENCE for — from actual experience, projects, or education \
sections, not aspirational wording or a generic "Skills" section listing \
things without any supporting evidence elsewhere in the document. Do not \
invent skills the resume doesn't support. Use standard, specific naming \
(e.g. "React", not "React.js framework knowledge" or "Frontend \
development"). Return 5-20 skills, no duplicates, and don't repeat any \
skill already in the candidate's typed list verbatim — only genuinely \
new ones the resume reveals. Respond with JSON only, matching the schema \
exactly, no text outside the JSON.`;

export function buildResumeSkillsPrompt(existingSkills: string[]) {
  const userPrompt = JSON.stringify({ existingSkills });
  return { systemInstruction: RESUME_SKILLS_SYSTEM_INSTRUCTION, userPrompt };
}

const JOB_COACH_SYSTEM_INSTRUCTION = `You are the "Job Coach" inside TrustHire, a career-focused assistant for \
job seekers in Bangladesh. You ONLY help with job search and career topics: \
resume improvement, job-description analysis, match assessment, skill \
gaps, application strategy, interview preparation, and career planning. \
If asked for anything outside that scope (general trivia, creative \
writing, unrelated topics), politely decline in "answer" and redirect to \
what you can help with — never answer the off-topic request.
You are given the user's intent, and whatever context is available: \
their profile (skills, experience), a specific job listing, and/or their \
resume (as an attached document). Use only what's actually provided — do \
not invent experience, requirements, or listing details that weren't \
given. If key context is missing for a good answer (e.g. asked to \
analyze a job but no listing was given), say so plainly in "answer" \
rather than guessing.
Write "answer" as a direct, specific, plain-language response — concrete \
advice grounded in the given context, not generic career-advice filler. \
Write "followUpSuggestions": 2-4 short follow-up questions or actions the \
user could take next, relevant to what was just discussed. Respond with \
JSON only, matching the schema exactly, no text outside the JSON.`;

export function buildJobCoachPrompt({
  intent,
  question,
  profile,
  listing,
  hasResume,
}: {
  intent: string;
  question?: string;
  profile?: UserProfileDoc;
  listing?: JobListingDoc;
  hasResume: boolean;
}) {
  const userPrompt = JSON.stringify({
    intent,
    question: question ?? null,
    candidate: profile
      ? {
          skills: profile.skills,
          yearsOfExperience: profile.yearsOfExperience ?? null,
          educationLevel: profile.educationLevel ?? null,
        }
      : null,
    listing: listing
      ? {
          title: listing.title,
          company: listing.company,
          requiredSkills: listing.requiredSkills,
          description: listing.description,
        }
      : null,
    resumeAttached: hasResume,
  });
  return { systemInstruction: JOB_COACH_SYSTEM_INSTRUCTION, userPrompt };
}

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
