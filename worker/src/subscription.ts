/**
 * The bdapps DCB sign-in flow, driven directly by this app's own native
 * UI rather than AppsPro's hosted checkout page or embedded WebSDK widget
 * — see docs/ARCHITECTURE.md → "Decision: AppsPro for bdapps DCB" for why
 * this replaced that earlier approach: operator selection (Robi/Cirkle)
 * has no equivalent in either of AppsPro's own UIs, and both of those
 * UIs' OTP verification happens in a context this Worker can't observe
 * directly, only infer from webhooks/postMessage events after the fact.
 *
 * There is no separate "account" system underneath this — phone+OTP IS
 * this app's sign-in, and a verified bdapps subscription IS the account
 * (there's no free tier, no "guest" mode; see `handleAuthOtpVerify` in
 * index.ts). Calling `/sdk/otp/request` and `/sdk/otp/verify` here means:
 *   - every privileged AppsPro call (Bearer `secret_key`) stays entirely
 *     server-side, never reaching the Flutter client — see this file's
 *     `callAppsPro`, the only place that header is attached.
 *   - the uid granting access is deterministic from the phone number
 *     itself (`uidForPhone`), minted into a real Firebase session via
 *     `mintFirebaseCustomToken` — the client never invents or chooses its
 *     own uid, and the same number always reaches the same profile.
 *
 * The webhook in `appspro.ts` still matters here: it's the only channel
 * for events this app didn't directly cause (a cancellation from BDApps'
 * own side, a renewal). This file only ever grants access in direct
 * response to a verify call *this* server just made and independently
 * confirmed — never on the strength of anything the client claims.
 *
 * One more hop, live in production: AppsPro's dashboard restricts its
 * Bearer-authed SDK API to an "Allowed Host Address(es)" list, but
 * Cloudflare Workers don't call out from one fixed IP (confirmed live —
 * three diagnostic requests each landed on a different Cloudflare edge
 * IP). `callAppsPro` below routes through `appspro-relay/` — a tiny
 * always-on VM with one real static IP — instead of calling
 * api.appspro.dev directly, whenever `APPSPRO_RELAY_URL`/
 * `APPSPRO_RELAY_SECRET` are configured. See that directory's README for
 * why and how it's deployed.
 */

import { bdOperatorForNormalizedPhone, normalizeBdPhoneNumber, phoneFromSubscriberId, uidForPhone } from './bdPhone';
import { grantPaidSubscription, revokePaidSubscription } from './appspro';
import { mintFirebaseCustomToken } from './firebaseCustomToken';
import { getDocument } from './firestoreClient';

interface Env {
  FIREBASE_PROJECT_ID: string;
  FIREBASE_CLIENT_EMAIL: string;
  FIREBASE_PRIVATE_KEY: string;
  APPSPRO_SECRET_KEY: string;
  /** Base URL of the static-IP relay (see `appspro-relay/`) — set once
   * that's deployed. Both this and `APPSPRO_RELAY_SECRET` must be present
   * for `callAppsPro` to route through it; either missing falls back to
   * calling AppsPro directly (useful before the relay exists, though in
   * production that path is currently blocked by AppsPro's own "Allowed
   * Host Address(es)" restriction — Cloudflare Workers don't call out
   * from one fixed IP, confirmed live across multiple requests each
   * landing on a different Cloudflare edge IP). Not sensitive itself —
   * a plain `wrangler.jsonc` var, not a secret. */
  APPSPRO_RELAY_URL?: string;
  /** Shared secret proving a request to the relay really came from this
   * Worker — see `appspro-relay/server.js`'s doc comment. Set via
   * `wrangler secret put APPSPRO_RELAY_SECRET`, matching whatever value
   * the relay's own `RELAY_SHARED_SECRET` env var holds. */
  APPSPRO_RELAY_SECRET?: string;
}

const APPSPRO_DIRECT_API_BASE = 'https://api.appspro.dev/api/v1';

/** AppsPro's own success sentinel — every SDK response includes
 * `status_code`, and "S1000"/"Success" is what a genuinely-successful
 * call looks like per its docs' examples. Anything else (wrong OTP,
 * expired reference_no, BDApps-side rejection, ...) is a real failure,
 * not a shape this app should try to interpret further — `status_detail`
 * already carries AppsPro's own explanation, which is surfaced verbatim
 * rather than replaced with a guessed-at message for a case its docs
 * don't enumerate. */
const APPSPRO_SUCCESS_STATUS_CODE = 'S1000';

export class AppsProApiError extends Error {}

interface OtpRequestResponse {
  reference_no?: string;
  status_code?: string;
  status_detail?: string;
}

interface OtpVerifyResponse {
  subscription_status?: string;
  subscriber_id?: string;
  local_subscriber_id?: string;
  status_code?: string;
  status_detail?: string;
}

interface VerifySubscriberResponse {
  valid?: boolean;
  subscriber?: { status?: string; [key: string]: unknown };
  reason?: string;
}

/** Routes through the static-IP relay when configured (see `Env`'s doc
 * comments above), otherwise calls AppsPro directly. The relay is a pure
 * hop — it forwards the `Authorization` header untouched, so the actual
 * AppsPro request/response shape is identical either way; only the
 * outbound IP AppsPro sees, and one extra `X-Relay-Secret` header for
 * that hop's own auth, differ. */
async function callAppsPro<T>(
  env: Env,
  method: 'GET' | 'POST',
  path: string,
  body?: Record<string, unknown>,
): Promise<T> {
  const useRelay = Boolean(env.APPSPRO_RELAY_URL && env.APPSPRO_RELAY_SECRET);
  const base = useRelay ? `${env.APPSPRO_RELAY_URL}/api/v1` : APPSPRO_DIRECT_API_BASE;

  let response: Response;
  try {
    response = await fetch(`${base}${path}`, {
      method,
      headers: {
        Authorization: `Bearer ${env.APPSPRO_SECRET_KEY}`,
        'Content-Type': 'application/json',
        ...(useRelay ? { 'X-Relay-Secret': env.APPSPRO_RELAY_SECRET! } : {}),
      },
      body: body ? JSON.stringify(body) : undefined,
    });
  } catch {
    throw new AppsProApiError('Could not reach AppsPro — check your connection and try again.');
  }

  let parsed: unknown;
  try {
    parsed = await response.json();
  } catch {
    throw new AppsProApiError('AppsPro returned an unreadable response.');
  }

  if (!response.ok) {
    const detail = (parsed as { status_detail?: string; detail?: string; message?: string } | null)?.status_detail
      ?? (parsed as { detail?: string } | null)?.detail
      ?? (parsed as { message?: string } | null)?.message;
    throw new AppsProApiError(detail || `AppsPro request failed (${response.status}).`);
  }

  return parsed as T;
}

/** Step 1-4 of the required flow: normalize, reject any operator other
 * than Robi/Cirkle (see `bdOperatorForNormalizedPhone`'s doc comment —
 * this is the authoritative check, independent of whatever the client's
 * operator picker showed), then ask AppsPro to send a real OTP SMS via
 * BDApps. No local OTP generation of any kind happens here or anywhere
 * else in this app. */
export async function requestOtp(env: Env, rawPhone: string): Promise<{ referenceNo: string; statusDetail: string }> {
  const normalized = normalizeBdPhoneNumber(rawPhone);
  const operator = bdOperatorForNormalizedPhone(normalized);
  if (!operator) {
    throw new AppsProApiError('This app only supports Robi (018) and Cirkle (016) numbers.');
  }

  const response = await callAppsPro<OtpRequestResponse>(env, 'POST', '/sdk/otp/request', { phone: normalized });
  if (response.status_code !== APPSPRO_SUCCESS_STATUS_CODE || !response.reference_no) {
    throw new AppsProApiError(response.status_detail || 'Could not send an OTP — try again.');
  }
  return { referenceNo: response.reference_no, statusDetail: response.status_detail ?? 'Success' };
}

/** Steps 5-9, and the whole sign-in: verify the OTP with AppsPro/BDApps
 * (never locally), then — critically — independently confirm the
 * resulting subscriber's status via `/sdk/verify/{subscriber_id}` before
 * granting anything. OTP-verify succeeding is BDApps' word that a
 * subscriber now exists; the follow-up `valid` check is AppsPro's own
 * word that it's actually active. Only once both agree does this derive
 * the account's uid from the phone number and mint a session for it — a
 * subscriber_id that OTP-verify just minted failing the follow-up check
 * would mean those two disagree with each other, which this is here to
 * catch, not paper over (step 10: no access without a positive
 * verification). Also doubles as the resubscribe path: a lapsed/canceled
 * subscriber runs through the exact same function, since signing back in
 * and reactivating are the same action once there's no separate account
 * system to keep signed in through a lapse. */
export async function verifyOtpAndSignIn(
  env: Env,
  referenceNo: string,
  otp: string,
): Promise<{ uid: string; customToken: string }> {
  const verifyResponse = await callAppsPro<OtpVerifyResponse>(env, 'POST', '/sdk/otp/verify', {
    reference_no: referenceNo,
    otp,
  });
  if (verifyResponse.status_code !== APPSPRO_SUCCESS_STATUS_CODE || !verifyResponse.subscriber_id) {
    throw new AppsProApiError(verifyResponse.status_detail || 'OTP verification failed.');
  }
  const subscriberId = verifyResponse.subscriber_id;

  const authoritative = await callAppsPro<VerifySubscriberResponse>(
    env,
    'GET',
    `/sdk/verify/${encodeURIComponent(subscriberId)}`,
  );
  if (!authoritative.valid) {
    throw new AppsProApiError(authoritative.reason || 'Subscription could not be verified — please try again.');
  }

  const phone = phoneFromSubscriberId(subscriberId);
  if (!phone) {
    // Shouldn't happen — AppsPro just handed this same value back from
    // otp/verify in the shape its own docs describe — but a malformed
    // subscriber_id can't be turned into a uid, so this can't proceed.
    throw new AppsProApiError('Could not identify the subscriber — please try again.');
  }
  const uid = uidForPhone(phone);

  await grantPaidSubscription(env, uid, subscriberId);
  const customToken = await mintFirebaseCustomToken(env, uid);
  return { uid, customToken };
}

/** "On future app launches, verify the subscription when appropriate
 * rather than permanently trusting a local boolean" — called from the
 * Subscription screen rather than on a timer, since that's the moment a
 * stale status would actually matter to the user. A no-op for anyone who
 * has never subscribed (nothing to refresh). */
export async function refreshSubscriptionStatus(env: Env, uid: string): Promise<void> {
  const existing = await getDocument(env, `subscriptions/${uid}`);
  const bdappsSubscriptionId = existing?.bdappsSubscriptionId;
  if (typeof bdappsSubscriptionId !== 'string') return;

  const authoritative = await callAppsPro<VerifySubscriberResponse>(
    env,
    'GET',
    `/sdk/verify/${encodeURIComponent(bdappsSubscriptionId)}`,
  );

  if (authoritative.valid) {
    await grantPaidSubscription(env, uid, bdappsSubscriptionId);
    return;
  }
  // AppsPro's `reason` string for an invalid subscriber isn't enumerated
  // in its docs beyond example values like "UNREGISTERED" — a loose
  // substring check is enough to tell an expiry apart from an outright
  // cancellation without pretending to know its full vocabulary.
  const reason = (authoritative.reason ?? '').toLowerCase();
  await revokePaidSubscription(env, uid, bdappsSubscriptionId, reason.includes('expir') ? 'expired' : 'canceled');
}
