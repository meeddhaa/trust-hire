/**
 * Mints a Firebase Auth custom token — the standard, documented JWT shape
 * `admin.auth().createCustomToken(uid)` produces, signed here directly
 * with the service account's own private key since Cloudflare Workers
 * can't run the Node-only Firebase Admin SDK. The client exchanges this
 * for a real session via `FirebaseAuth.signInWithCustomToken` (the
 * `firebase_auth` Flutter plugin calls Identity Toolkit's own
 * `signInWithCustomToken` REST endpoint itself — nothing else to build
 * client-side).
 *
 * This is now the ONLY way a user is ever signed into this app — see
 * `subscription.ts`'s `verifyOtpAndSignIn`: a verified bdapps subscription
 * IS the account, there's no separate email/password identity underneath
 * it. `uid` is always `uidForPhone(phone)` (see `bdPhone.ts`), so the same
 * phone number reaches the same Firestore profile on every subsequent
 * sign-in.
 */

import { signRs256Jwt } from './jwtSign';

interface Env {
  FIREBASE_CLIENT_EMAIL: string;
  FIREBASE_PRIVATE_KEY: string;
}

const IDENTITY_TOOLKIT_AUDIENCE =
  'https://identitytoolkit.googleapis.com/google.identity.identitytoolkit.v1.IdentityToolkit';

/** Custom tokens are capped at 1 hour by Identity Toolkit regardless of
 * what `exp` claims — this just matches that ceiling. The session the
 * client actually gets after exchanging it is a normal, auto-refreshing
 * Firebase Auth session (a Firebase ID token, not this JWT itself), so
 * this short lifetime only bounds the one-time exchange window, not how
 * long the user stays signed in. */
const CUSTOM_TOKEN_TTL_SECONDS = 3600;

export async function mintFirebaseCustomToken(env: Env, uid: string): Promise<string> {
  const nowSeconds = Math.floor(Date.now() / 1000);
  return signRs256Jwt(env.FIREBASE_PRIVATE_KEY, {
    iss: env.FIREBASE_CLIENT_EMAIL,
    sub: env.FIREBASE_CLIENT_EMAIL,
    aud: IDENTITY_TOOLKIT_AUDIENCE,
    iat: nowSeconds,
    exp: nowSeconds + CUSTOM_TOKEN_TTL_SECONDS,
    uid,
  });
}
