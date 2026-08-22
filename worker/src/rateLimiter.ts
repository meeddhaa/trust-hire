/**
 * Cheap, eventually-consistent per-user daily cap on LLM calls — per the
 * brief, "basic rate limiting per user." A KV read/write per request is
 * fine for this; we don't need Durable Objects' strict consistency, since
 * a race under concurrent requests can only ever let a user go a little
 * over the cap for one day, not compromise anything.
 *
 * Only called on an actual Gemini call (a cache hit in index.ts returns
 * before this runs) — so re-opening an already-assessed listing never
 * costs quota, matching the brief's "doesn't burn API quota per listing
 * view" principle.
 */

interface Env {
  RATE_LIMIT_KV: KVNamespace;
  RATE_LIMIT_PER_USER_PER_DAY: string;
}

const TTL_SECONDS = 2 * 24 * 60 * 60; // 2 days — one day of headroom past the UTC date rollover

function todayKey(uid: string): string {
  const utcDate = new Date().toISOString().slice(0, 10); // YYYY-MM-DD
  return `ratelimit:${uid}:${utcDate}`;
}

export interface RateLimitResult {
  allowed: boolean;
  limit: number;
  remaining: number;
}

export async function checkAndConsumeRateLimit(env: Env, uid: string): Promise<RateLimitResult> {
  const limit = Number.parseInt(env.RATE_LIMIT_PER_USER_PER_DAY, 10);
  const key = todayKey(uid);

  const currentRaw = await env.RATE_LIMIT_KV.get(key);
  const current = currentRaw ? Number.parseInt(currentRaw, 10) : 0;

  if (current >= limit) {
    return { allowed: false, limit, remaining: 0 };
  }

  await env.RATE_LIMIT_KV.put(key, String(current + 1), { expirationTtl: TTL_SECONDS });
  return { allowed: true, limit, remaining: limit - current - 1 };
}
