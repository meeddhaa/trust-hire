/**
 * Google service-account OAuth token exchange (JWT bearer flow) for
 * `firestoreClient.ts` — the Firestore Admin-equivalent credential that
 * bypasses `firestore.rules` for matchResults/scamAssessments writes.
 *
 * Previously also covered a Cloud Storage read scope for resume-tailoring
 * (a `storageClient.ts` fetched an uploaded resume from a separate file
 * store); removed once resume storage moved to a base64 field directly on
 * the profile doc — see "Decision: resume storage, twice reconsidered" in
 * docs/ARCHITECTURE.md. One less scope, one less client, same Firestore
 * read now covers both profile and resume.
 *
 * The token is cached at module scope and refreshed proactively before
 * expiry — a shared, non-request-specific credential (like the JWKS
 * cache in auth.ts), not per-request state.
 */

import { signRs256Jwt } from './jwtSign';

interface Env {
  FIREBASE_CLIENT_EMAIL: string;
  FIREBASE_PRIVATE_KEY: string;
}

interface CachedToken {
  accessToken: string;
  expiresAtMs: number;
}

const SCOPES = 'https://www.googleapis.com/auth/datastore';

let tokenCache: CachedToken | null = null;

async function fetchAccessToken(env: Env): Promise<CachedToken> {
  const nowSeconds = Math.floor(Date.now() / 1000);
  const jwt = await signRs256Jwt(env.FIREBASE_PRIVATE_KEY, {
    iss: env.FIREBASE_CLIENT_EMAIL,
    scope: SCOPES,
    aud: 'https://oauth2.googleapis.com/token',
    iat: nowSeconds,
    exp: nowSeconds + 3600,
  });

  const res = await fetch('https://oauth2.googleapis.com/token', {
    method: 'POST',
    headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
    body: new URLSearchParams({
      grant_type: 'urn:ietf:params:oauth:grant-type:jwt-bearer',
      assertion: jwt,
    }),
  });
  if (!res.ok) {
    throw new Error(`Service account token exchange failed: ${res.status} ${await res.text()}`);
  }
  const body = await res.json<{ access_token: string; expires_in: number }>();
  return { accessToken: body.access_token, expiresAtMs: Date.now() + body.expires_in * 1000 };
}

export async function getServiceAccountAccessToken(env: Env): Promise<string> {
  const REFRESH_MARGIN_MS = 5 * 60 * 1000;
  if (tokenCache && Date.now() < tokenCache.expiresAtMs - REFRESH_MARGIN_MS) {
    return tokenCache.accessToken;
  }
  tokenCache = await fetchAccessToken(env);
  return tokenCache.accessToken;
}
