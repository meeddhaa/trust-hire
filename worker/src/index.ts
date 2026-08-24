import { AuthError, extractBearerToken, verifyFirebaseIdToken } from './auth';
import { getDocument, setDocument } from './firestoreClient';
import { callGeminiForJson, GeminiError } from './gemini';
import { buildMatchPrompt, buildScamPrompt, MATCH_RESPONSE_SCHEMA, SCAM_RESPONSE_SCHEMA } from './prompts';
import { checkAndConsumeRateLimit } from './rateLimiter';
import { bandTrustBadge, computeRuleScore, computeScamRuleFlags } from './scamRules';
import type { JobListingDoc, MatchGeminiResult, ScamGeminiResult, UserProfileDoc } from './types';

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
