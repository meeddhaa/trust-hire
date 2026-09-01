import { AppsProSignatureError, handleAppsProWebhook, verifyAppsProSignature } from './appspro';
import { AuthError, extractBearerToken, verifyFirebaseIdToken } from './auth';
import { getDocument, setDocument } from './firestoreClient';
import { callGeminiForJson, GeminiError } from './gemini';
import {
  buildJobCoachPrompt,
  buildMatchPrompt,
  buildResumeSkillsPrompt,
  buildResumeTailorPrompt,
  buildScamPrompt,
  JOB_COACH_RESPONSE_SCHEMA,
  MATCH_RESPONSE_SCHEMA,
  RESUME_SKILLS_RESPONSE_SCHEMA,
  RESUME_TAILOR_RESPONSE_SCHEMA,
  SCAM_RESPONSE_SCHEMA,
} from './prompts';
import { checkAndConsumeRateLimit } from './rateLimiter';
import { bandTrustBadge, computeRuleScore, computeScamRuleFlags } from './scamRules';
import { AppsProApiError, refreshSubscriptionStatus, requestOtp, verifyOtpAndSignIn } from './subscription';
import type {
  JobCoachGeminiResult,
  JobListingDoc,
  MatchGeminiResult,
  ResumeSkillsGeminiResult,
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

/** Shared by the subscription-refresh route so the client always gets
 * back the same shape `Subscription.fromMap` already knows how to parse
 * (see `lib/data/models/subscription.dart`) — the same pattern
 * `handleMatch` uses for `MatchResult`. */
async function currentSubscriptionJson(env: Env, uid: string): Promise<Record<string, unknown>> {
  return (await getDocument(env, `subscriptions/${uid}`)) ?? { tier: 'free', status: 'none' };
}

/** No `requireUid` — there's no session yet at this point, that's the
 * whole reason this route exists. Wired *before* `requireUid` in `fetch`,
 * same reasoning as the AppsPro webhook route below. */
async function handleAuthOtpRequest(request: Request, env: Env): Promise<Response> {
  const body = await request.json<{ phone?: unknown }>().catch(() => null);
  if (typeof body?.phone !== 'string' || !body.phone.trim()) {
    throw new TypeError('Request body must include a non-empty "phone" string');
  }
  const { referenceNo, statusDetail } = await requestOtp(env, body.phone);
  return json({ referenceNo, statusDetail });
}

/** Verifies the OTP, independently confirms the subscription, and mints a
 * Firebase custom token for the resulting (deterministic, phone-derived)
 * uid — see `subscription.ts`'s `verifyOtpAndSignIn`. The client exchanges
 * `customToken` for a real session via `signInWithCustomToken`; this
 * route itself never sees a Firebase ID token, since none exists yet. */
async function handleAuthOtpVerify(request: Request, env: Env): Promise<Response> {
  const body = await request.json<{ referenceNo?: unknown; otp?: unknown }>().catch(() => null);
  if (typeof body?.referenceNo !== 'string' || !body.referenceNo.trim()) {
    throw new TypeError('Request body must include a non-empty "referenceNo" string');
  }
  if (typeof body?.otp !== 'string' || !body.otp.trim()) {
    throw new TypeError('Request body must include a non-empty "otp" string');
  }
  const { uid, customToken } = await verifyOtpAndSignIn(env, body.referenceNo, body.otp);
  return json({ uid, customToken });
}

async function handleSubscriptionRefresh(env: Env, uid: string): Promise<Response> {
  await refreshSubscriptionStatus(env, uid);
  return json(await currentSubscriptionJson(env, uid));
}

async function handleExtractResumeSkills(request: Request, env: Env, uid: string): Promise<Response> {
  const body = await request.json<{ existingSkills?: unknown }>().catch(() => null);
  const existingSkills = Array.isArray(body?.existingSkills)
    ? body.existingSkills.filter((s): s is string => typeof s === 'string')
    : [];

  const profile = await getDocument(env, `users/${uid}`);
  const resumeBase64 = (profile as unknown as UserProfileDoc | null)?.resumeBase64;
  if (!resumeBase64) return errorResponse(404, 'Upload a resume first');

  const rateLimit = await checkAndConsumeRateLimit(env, uid);
  if (!rateLimit.allowed) {
    return errorResponse(429, `Daily AI request limit (${rateLimit.limit}) reached — try again tomorrow`);
  }

  const { systemInstruction, userPrompt } = buildResumeSkillsPrompt(existingSkills);
  const result = await callGeminiForJson<ResumeSkillsGeminiResult>(
    env,
    systemInstruction,
    userPrompt,
    RESUME_SKILLS_RESPONSE_SCHEMA,
    [{ mimeType: 'application/pdf', base64Data: resumeBase64 }],
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

    // Checked before requireUid deliberately — this request comes from
    // AppsPro's own server, not our Flutter client, so it carries no
    // Firebase ID token at all. Its authenticity instead rests entirely
    // on the HMAC signature verified inside — see appspro.ts's doc
    // comment for why that has to be this route's whole auth story.
    if (url.pathname === '/v1/appspro-webhook') {
      try {
        const body = await request.json<{ event?: unknown; data?: unknown }>().catch(() => null);
        if (!body || typeof body.event !== 'string' || typeof body.data !== 'object' || body.data === null) {
          return errorResponse(400, 'Malformed webhook body');
        }
        const parsedBody = { event: body.event, data: body.data as Record<string, unknown> };
        await verifyAppsProSignature(env, parsedBody, request.headers.get('X-Signature'));
        await handleAppsProWebhook(env, parsedBody);
        return json({ ok: true });
      } catch (err) {
        if (err instanceof AppsProSignatureError) return errorResponse(401, err.message);
        console.error('AppsPro webhook handling failed:', err);
        return errorResponse(500, 'Internal error');
      }
    }

    // Also checked before requireUid, deliberately, and for the same
    // reason as the webhook above: there is no Firebase session yet at
    // this point in the sign-in flow — these two routes are what
    // *creates* one. See `handleAuthOtpVerify`'s doc comment.
    if (url.pathname === '/v1/auth/otp/request' || url.pathname === '/v1/auth/otp/verify') {
      try {
        if (url.pathname === '/v1/auth/otp/request') return await handleAuthOtpRequest(request, env);
        return await handleAuthOtpVerify(request, env);
      } catch (err) {
        if (err instanceof AppsProApiError) return errorResponse(400, err.message);
        if (err instanceof TypeError) return errorResponse(400, err.message);
        console.error('Auth OTP handling failed:', err);
        return errorResponse(500, 'Internal error');
      }
    }

    try {
      const uid = await requireUid(request, env);

      if (url.pathname === '/v1/match') return await handleMatch(request, env, uid);
      if (url.pathname === '/v1/scam-assessment') return await handleScamAssessment(request, env, uid);
      if (url.pathname === '/v1/resume-tailor') return await handleResumeTailor(request, env, uid);
      if (url.pathname === '/v1/job-coach') return await handleJobCoach(request, env, uid);
      if (url.pathname === '/v1/resume-skills') return await handleExtractResumeSkills(request, env, uid);
      if (url.pathname === '/v1/subscription/refresh') return await handleSubscriptionRefresh(env, uid);
      return errorResponse(404, 'Unknown endpoint');
    } catch (err) {
      if (err instanceof AuthError) return errorResponse(401, err.message);
      if (err instanceof AppsProApiError) return errorResponse(400, err.message);
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
