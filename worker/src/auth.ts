/**
 * Verifies a Firebase Auth ID token without pulling in the Admin SDK
 * (which assumes a Node server, not a Workers isolate). This is the
 * Worker's actual trust boundary: everything downstream (rate limiting,
 * Firestore writes) uses the `uid` this returns, and Firestore writes go
 * through a service account that bypasses `firestore.rules` entirely — so
 * an unverified or forged token here would let anyone write fabricated
 * match results or scam assessments for any user.
 *
 * Firebase ID tokens are RS256 JWTs signed by Google's `securetoken`
 * service. We fetch its public JWKS, verify the signature with Web
 * Crypto, and check the standard Firebase claims (issuer, audience,
 * expiry). The JWKS is cached at module scope across requests — it's
 * Google's public key material, not per-request data, so this is a plain
 * cache, not the "global request state" anti-pattern.
 */

interface Jwk {
  kid: string;
  n: string;
  e: string;
  kty: string;
  alg: string;
}

interface CachedJwks {
  keys: Jwk[];
  fetchedAtMs: number;
}

const JWKS_URL = 'https://www.googleapis.com/service_accounts/v1/jwk/securetoken@system.gserviceaccount.com';
const JWKS_TTL_MS = 60 * 60 * 1000; // 1 hour — Google rotates these infrequently

let jwksCache: CachedJwks | null = null;

async function getJwks(): Promise<Jwk[]> {
  if (jwksCache && Date.now() - jwksCache.fetchedAtMs < JWKS_TTL_MS) {
    return jwksCache.keys;
  }
  const res = await fetch(JWKS_URL);
  if (!res.ok) {
    throw new AuthError('Failed to fetch Firebase public keys');
  }
  const body = await res.json<{ keys: Jwk[] }>();
  jwksCache = { keys: body.keys, fetchedAtMs: Date.now() };
  return body.keys;
}

export class AuthError extends Error {}

function base64UrlToBytes(b64url: string): Uint8Array {
  const b64 = b64url.replace(/-/g, '+').replace(/_/g, '/').padEnd(Math.ceil(b64url.length / 4) * 4, '=');
  const binary = atob(b64);
  const bytes = new Uint8Array(binary.length);
  for (let i = 0; i < binary.length; i++) bytes[i] = binary.charCodeAt(i);
  return bytes;
}

function base64UrlToJson<T>(b64url: string): T {
  return JSON.parse(new TextDecoder().decode(base64UrlToBytes(b64url))) as T;
}

/** Returns the verified `uid`, or throws `AuthError` with a message safe
 * to surface to the client (no internals). */
export async function verifyFirebaseIdToken(idToken: string, projectId: string): Promise<string> {
  const parts = idToken.split('.');
  if (parts.length !== 3) throw new AuthError('Malformed token');
  const [headerB64, payloadB64, signatureB64] = parts as [string, string, string];

  const header = base64UrlToJson<{ kid?: string; alg?: string }>(headerB64);
  if (header.alg !== 'RS256' || !header.kid) throw new AuthError('Unsupported token header');

  const keys = await getJwks();
  const jwk = keys.find((k) => k.kid === header.kid);
  if (!jwk) throw new AuthError('Unknown signing key');

  const cryptoKey = await crypto.subtle.importKey(
    'jwk',
    { kty: jwk.kty, n: jwk.n, e: jwk.e, alg: 'RS256', ext: true },
    { name: 'RSASSA-PKCS1-v1_5', hash: 'SHA-256' },
    false,
    ['verify'],
  );

  const signedData = new TextEncoder().encode(`${headerB64}.${payloadB64}`);
  const signature = base64UrlToBytes(signatureB64);
  const validSignature = await crypto.subtle.verify('RSASSA-PKCS1-v1_5', cryptoKey, signature, signedData);
  if (!validSignature) throw new AuthError('Invalid token signature');

  const payload = base64UrlToJson<{
    iss?: string;
    aud?: string;
    exp?: number;
    iat?: number;
    sub?: string;
  }>(payloadB64);

  const nowSeconds = Date.now() / 1000;
  if (payload.iss !== `https://securetoken.google.com/${projectId}`) {
    throw new AuthError('Wrong token issuer');
  }
  if (payload.aud !== projectId) throw new AuthError('Wrong token audience');
  if (!payload.exp || payload.exp < nowSeconds) throw new AuthError('Token expired');
  if (!payload.iat || payload.iat > nowSeconds + 60) throw new AuthError('Token issued in the future');
  if (!payload.sub) throw new AuthError('Token missing subject');

  return payload.sub;
}

export function extractBearerToken(request: Request): string | null {
  const header = request.headers.get('Authorization');
  if (!header?.startsWith('Bearer ')) return null;
  return header.slice('Bearer '.length).trim() || null;
}
