/**
 * Minimal RS256 JWT signing, shared by the two things in this Worker that
 * need to sign a JWT with the Firebase service account's own private key:
 * the Google OAuth2 service-account token exchange (`serviceAccountAuth.ts`,
 * for Firestore REST access) and minting a Firebase Auth custom token
 * (`firebaseCustomToken.ts`, for the phone+OTP sign-in flow). Cloudflare
 * Workers has no Node `crypto`/`jsonwebtoken` — this is the whole
 * implementation, built directly on Web Crypto.
 */

function base64UrlEncode(bytes: ArrayBuffer | Uint8Array): string {
  const arr = bytes instanceof Uint8Array ? bytes : new Uint8Array(bytes);
  let binary = '';
  for (const byte of arr) binary += String.fromCharCode(byte);
  return btoa(binary).replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/, '');
}

function pemToPkcs8(pem: string): ArrayBuffer {
  const base64 = pem
    .replace(/-----BEGIN PRIVATE KEY-----/, '')
    .replace(/-----END PRIVATE KEY-----/, '')
    .replace(/\s/g, '');
  const binary = atob(base64);
  const bytes = new Uint8Array(binary.length);
  for (let i = 0; i < binary.length; i++) bytes[i] = binary.charCodeAt(i);
  return bytes.buffer;
}

/** Signs `payload` (with a standard `{alg:"RS256",typ:"JWT"}` header) using
 * `privateKeyPem` (a Google service account's PKCS8 PEM private key) and
 * returns the complete `header.payload.signature` JWT string. */
export async function signRs256Jwt(privateKeyPem: string, payload: Record<string, unknown>): Promise<string> {
  const header = base64UrlEncode(new TextEncoder().encode(JSON.stringify({ alg: 'RS256', typ: 'JWT' })));
  const encodedPayload = base64UrlEncode(new TextEncoder().encode(JSON.stringify(payload)));

  const key = await crypto.subtle.importKey(
    'pkcs8',
    pemToPkcs8(privateKeyPem),
    { name: 'RSASSA-PKCS1-v1_5', hash: 'SHA-256' },
    false,
    ['sign'],
  );
  const signature = await crypto.subtle.sign(
    'RSASSA-PKCS1-v1_5',
    key,
    new TextEncoder().encode(`${header}.${encodedPayload}`),
  );
  return `${header}.${encodedPayload}.${base64UrlEncode(signature)}`;
}
