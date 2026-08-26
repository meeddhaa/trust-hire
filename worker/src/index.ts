import { AuthError, extractBearerToken, verifyFirebaseIdToken } from './auth';
import { getDocument, setDocument } from './firestoreClient';
import { callGeminiForJson, GeminiError } from './gemini';
import {
  buildJobCoachPrompt,
  buildMatchPrompt,
  buildResumeTailorPrompt,
  buildScamPrompt,
  JOB_COACH_RESPONSE_SCHEMA,
  MATCH_RESPONSE_SCHEMA,
  RESUME_TAILOR_RESPONSE_SCHEMA,
  SCAM_RESPONSE_SCHEMA,
} from './prompts';
import { checkAndConsumeRateLimit } from './rateLimiter';
import { bandTrustBadge, computeRuleScore, computeScamRuleFlags } from './scamRules';
import type {
  JobCoachGeminiResult,
  JobListingDoc,
  MatchGeminiResult,
  ResumeTailorGeminiResult,
  ScamGeminiResult,
  UserProfileDoc,
} from './types';

/**
 * Cloudflare Worker: the Gemini relay named in the brief. Holds the API
 * key server-side, verifies the caller's Firebase identity, rate-limits
 * per user, and caches results back to Firestore so re-opening a listing
 * never re-spends LLM quota. See docs/ARCHITECTURE.md → "Data flow: match
 * + scam assessment" for the end-to-end picture, and worker/README.md for
 * deploy/secrets setup.
 */

function json(data: unknown, status = 200): Response {
  return new Response(JSON.stringify(data), {
    status,
    headers: { 'Content-Type': 'application/json' },
  });
}

function errorResponse(status: number, message: string): Response {
  return json({ error: message }, status);
}

async function requireUid(request: Request, env: Env): Promise<string> {
  const token = extractBearerToken(request);
  if (!token) throw new AuthError('Missing Authorization header');
  return verifyFirebaseIdToken(token, env.FIREBASE_PROJECT_ID);
}

async function readListingId(request: Request): Promise<string> {
  const body = await request.json<{ listingId?: unknown }>().catch(() => null);
  const listingId = body?.listingId;
  if (typeof listingId !== 'string' || !listingId.trim()) {
    throw new TypeError('Request body must include a non-empty "listingId" string');
  }
  return listingId;
}

async function handleMatch(request: Request, env: Env, uid: string): Promise<Response> {
  const listingId = await readListingId(request);

  const listing = await getDocument(env, `listings/${listingId}`);
  if (!listing) return errorResponse(404, `No listing with id "${listingId}"`);

  const profile = await getDocument(env, `users/${uid}`);
  if (!profile) return errorResponse(404, 'Complete onboarding before requesting a match');

  const matchId = `${uid}_${listingId}`;
  const cached = await getDocument(env, `matchResults/${matchId}`);
  if (cached && cached.modelVersion === env.MATCH_MODEL_VERSION) {
    return json({ id: matchId, ...cached });
  }

  const rateLimit = await checkAndConsumeRateLimit(env, uid);
  if (!rateLimit.allowed) {
    return errorResponse(429, `Daily AI request limit (${rateLimit.limit}) reached — try again tomorrow`);
  }

  const { systemInstruction, userPrompt } = buildMatchPrompt(
    profile as unknown as UserProfileDoc,
    listing as unknown as JobListingDoc,
  );
  const result = await callGeminiForJson<MatchGeminiResult>(
    env,
    systemInstruction,
    userPrompt,
    MATCH_RESPONSE_SCHEMA,
  );

  const computedAt = new Date();
  const doc = {
    userId: uid,
    listingId,
    matchPercent: result.matchPercent,
    matchedSkills: result.matchedSkills,
    gapSkills: result.gapSkills,
    reasoning: result.reasoning,
    upskillingRoadmap: result.upskillingRoadmap,
    computedAt,
    modelVersion: env.MATCH_MODEL_VERSION,
  };
  await setDocument(env, `matchResults/${matchId}`, doc);

  return json({ id: matchId, ...doc, computedAt: computedAt.toISOString() });
}

async function handleScamAssessment(request: Request, env: Env, uid: string): Promise<Response> {
  const listingId = await readListingId(request);

  const listing = await getDocument(env, `listings/${listingId}`);
  if (!listing) return errorResponse(404, `No listing with id "${listingId}"`);
  const listingDoc = listing as unknown as JobListingDoc;

  const cached = await getDocument(env, `scamAssessments/${listingId}`);
  if (cached && cached.modelVersion === env.SCAM_MODEL_VERSION) {
    return json({ listingId, ...cached });
  }

  const rateLimit = await checkAndConsumeRateLimit(env, uid);
  if (!rateLimit.allowed) {
    return errorResponse(429, `Daily AI request limit (${rateLimit.limit}) reached — try again tomorrow`);
  }

  // Recomputed server-side (not trusting client-supplied flags) because
  // this assessment is cached once and shared by every user — see the doc
  // comment in scamRules.ts.
  const ruleFlags = computeScamRuleFlags(listingDoc);
  const ruleScore = computeRuleScore(ruleFlags);
  const trustBadge = bandTrustBadge(ruleScore);

  const { systemInstruction, userPrompt } = buildScamPrompt(listingDoc, ruleFlags);
  const result = await callGeminiForJson<ScamGeminiResult>(
    env,
    systemInstruction,
    userPrompt,
    SCAM_RESPONSE_SCHEMA,
  );

  const computedAt = new Date();
  const doc = {
    ruleFlags,
    ruleScore,
    trustBadge,
    reasoning: result.reasoning,
    computedAt,
    modelVersion: env.SCAM_MODEL_VERSION,
  };
  await setDocument(env, `scamAssessments/${listingId}`, doc);

  return json({ listingId, ...doc, computedAt: computedAt.toISOString() });
}

async function handleResumeTailor(request: Request, env: Env, uid: string): Promise<Response> {
  const listingId = await readListingId(request);

  const listing = await getDocument(env, `listings/${listingId}`);
  if (!listing) return errorResponse(404, `No listing with id "${listingId}"`);

  // Resume lives as a base64 field on the profile doc itself (see
  // "Decision: resume storage, twice reconsidered" in docs/ARCHITECTURE.md
  // for why this isn't a separate file store) — one Firestore read covers
  // both the profile and the resume, no separate storage client needed.
  const profile = await getDocument(env, `users/${uid}`);
  const resumeBase64 = (profile as unknown as UserProfileDoc | null)?.resumeBase64;
  if (!resumeBase64) return errorResponse(404, 'Upload a resume in Settings before tailoring it');

  const rateLimit = await checkAndConsumeRateLimit(env, uid);
  if (!rateLimit.allowed) {
    return errorResponse(429, `Daily AI request limit (${rateLimit.limit}) reached — try again tomorrow`);
  }

  const { systemInstruction, userPrompt } = buildResumeTailorPrompt(listing as unknown as JobListingDoc);
  const result = await callGeminiForJson<ResumeTailorGeminiResult>(
    env,
    systemInstruction,
    userPrompt,
    RESUME_TAILOR_RESPONSE_SCHEMA,
    [{ mimeType: 'application/pdf', base64Data: resumeBase64 }],
  );

  return json({ listingId, ...result });
}

const JOB_COACH_INTENTS = new Set([
  'improve_resume',
  'analyze_job',
  'interview_prep',
  'skill_gaps',
  'career_guidance',
  'custom',
]);

async function handleJobCoach(request: Request, env: Env, uid: string): Promise<Response> {
  const body = await request
    .json<{ intent?: unknown; question?: unknown; listingId?: unknown }>()
    .catch(() => null);
  const intent = body?.intent;
  if (typeof intent !== 'string' || !JOB_COACH_INTENTS.has(intent)) {
    throw new TypeError(`Request body must include a valid "intent" (one of: ${[...JOB_COACH_INTENTS].join(', ')})`);
  }
  const question = typeof body?.question === 'string' ? body.question : undefined;
  const listingId = typeof body?.listingId === 'string' ? body.listingId : undefined;

  const profile = await getDocument(env, `users/${uid}`);
  const listing = listingId ? await getDocument(env, `listings/${listingId}`) : null;
  const resumeBase64 = (profile as unknown as UserProfileDoc | null)?.resumeBase64;

  const rateLimit = await checkAndConsumeRateLimit(env, uid);
  if (!rateLimit.allowed) {
    return errorResponse(429, `Daily AI request limit (${rateLimit.limit}) reached — try again tomorrow`);
  }

  const { systemInstruction, userPrompt } = buildJobCoachPrompt({
    intent,
    question,
    profile: (profile as unknown as UserProfileDoc) ?? undefined,
    listing: (listing as unknown as JobListingDoc) ?? undefined,
    hasResume: resumeBase64 != null,
  });
  const result = await callGeminiForJson<JobCoachGeminiResult>(
    env,
    systemInstruction,
    userPrompt,
    JOB_COACH_RESPONSE_SCHEMA,
    resumeBase64 ? [{ mimeType: 'application/pdf', base64Data: resumeBase64 }] : [],
  );

  return json(result);
}

export default {
  async fetch(request: Request, env: Env): Promise<Response> {
    const url = new URL(request.url);

    if (request.method === 'GET' && url.pathname === '/') {
      return json({ ok: true, service: 'trusthire-ai-relay' });
    }

    if (request.method !== 'POST') {
      return errorResponse(405, 'Method not allowed');
    }

    try {
      const uid = await requireUid(request, env);

      if (url.pathname === '/v1/match') return await handleMatch(request, env, uid);
      if (url.pathname === '/v1/scam-assessment') return await handleScamAssessment(request, env, uid);
      if (url.pathname === '/v1/resume-tailor') return await handleResumeTailor(request, env, uid);
      if (url.pathname === '/v1/job-coach') return await handleJobCoach(request, env, uid);
      return errorResponse(404, 'Unknown endpoint');
    } catch (err) {
      if (err instanceof AuthError) return errorResponse(401, err.message);
      if (err instanceof TypeError) return errorResponse(400, err.message);
      if (err instanceof GeminiError) {
        console.error('Gemini call failed:', err.message);
        return errorResponse(502, 'AI provider error, try again shortly');
      }
      console.error('Unhandled Worker error:', err);
      return errorResponse(500, 'Internal error');
    }
  },
} satisfies ExportedHandler<Env>;
