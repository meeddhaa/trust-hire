/**
 * AppsPro (bdapps DCB subscription platform) inbound webhook handling.
 *
 * AppsPro — not bdapps directly — is the layer this app integrates with;
 * see docs/ARCHITECTURE.md → "Decision: AppsPro for bdapps DCB". AppsPro's
 * server calls this Worker whenever a subscriber's status changes; there's
 * no Firebase ID token on these requests (they're not from our own
 * client), so authenticity instead rests entirely on the HMAC signature
 * verified below — this route MUST be reached before `requireUid` in
 * index.ts, not after.
 *
 * The one real integration gap: AppsPro's hosted checkout has no way to
 * carry our own uid through to the webhook — it only ever gives back the
 * subscriber's phone number. So phone number is the join key: the app
 * collects it once (see ProfileRepository.setPhoneNumber) before sending
 * the user to checkout, and every webhook here looks the matching user up
 * by that field rather than trusting any uid the payload might claim.
 */

import { getDocument, queryCollection, setDocument } from './firestoreClient';

interface Env {
  FIREBASE_PROJECT_ID: string;
  FIREBASE_CLIENT_EMAIL: string;
  FIREBASE_PRIVATE_KEY: string;
  APPSPRO_SECRET_KEY: string;
}

interface AppsProWebhookBody {
  event: string;
  data: Record<string, unknown>;
}

/** Recreates Python's `json.dumps(obj, sort_keys=True)` byte-for-byte —
 * AppsPro signs that exact canonical form (see their docs' "Webhooks"
 * section), and `JSON.stringify` alone doesn't match it: Python's default
 * separators are `", "` / `": "` (with spaces), and its default
 * `ensure_ascii=True` escapes every non-ASCII character as `\uXXXX`.
 * Getting either of those wrong makes every signature check fail, not
 * just unusual-input ones — this has to mirror Python exactly. */
function canonicalize(value: unknown): string {
  if (value === null || value === undefined) return 'null';
  if (typeof value === 'boolean') return value ? 'true' : 'false';
  if (typeof value === 'number') return String(value);
  if (typeof value === 'string') return canonicalizeString(value);
  if (Array.isArray(value)) return `[${value.map(canonicalize).join(', ')}]`;
  if (typeof value === 'object') {
    const entries = Object.entries(value as Record<string, unknown>).sort(([a], [b]) => (a < b ? -1 : a > b ? 1 : 0));
    return `{${entries.map(([k, v]) => `${canonicalizeString(k)}: ${canonicalize(v)}`).join(', ')}}`;
  }
  throw new TypeError(`Cannot canonicalize value for signature check: ${typeof value}`);
}

function canonicalizeString(s: string): string {
  let out = '"';
  for (const ch of s) {
    const code = ch.codePointAt(0)!;
    if (ch === '"') out += '\\"';
    else if (ch === '\\') out += '\\\\';
    else if (ch === '\n') out += '\\n';
    else if (ch === '\r') out += '\\r';
    else if (ch === '\t') out += '\\t';
    else if (code < 0x20 || code > 0x7e) {
      // ensure_ascii=True: escape as \uXXXX (surrogate pair for anything
      // outside the BMP, matching what Python's json module emits).
      if (code > 0xffff) {
        const high = 0xd800 + ((code - 0x10000) >> 10);
        const low = 0xdc00 + ((code - 0x10000) & 0x3ff);
        out += `\\u${high.toString(16).padStart(4, '0')}\\u${low.toString(16).padStart(4, '0')}`;
      } else {
        out += `\\u${code.toString(16).padStart(4, '0')}`;
      }
    } else out += ch;
  }
  return out + '"';
}

async function hmacHex(key: string, message: string): Promise<string> {
  const cryptoKey = await crypto.subtle.importKey(
    'raw',
    new TextEncoder().encode(key),
    { name: 'HMAC', hash: 'SHA-256' },
    false,
    ['sign'],
  );
  const signature = await crypto.subtle.sign('HMAC', cryptoKey, new TextEncoder().encode(message));
  return [...new Uint8Array(signature)].map((b) => b.toString(16).padStart(2, '0')).join('');
}

/** Constant-time-ish string comparison — a plain `===` short-circuits on
 * the first differing character, which leaks timing information about how
 * many leading hex digits an attacker guessed correctly. Not the main
 * defense here (HTTPS + a long shared secret already rule out a
 * realistic timing attack for a hackathon-scale app), but cheap enough to
 * just do properly. */
function timingSafeEqual(a: string, b: string): boolean {
  if (a.length !== b.length) return false;
  let diff = 0;
  for (let i = 0; i < a.length; i++) diff |= a.charCodeAt(i) ^ b.charCodeAt(i);
  return diff === 0;
}

export class AppsProSignatureError extends Error {}

/** Verifies `X-Signature` against the canonical form of the ALREADY-PARSED
 * body — not the raw request bytes. AppsPro's own docs call this out
 * explicitly ("Comparing raw request bytes will not work in most
 * frameworks"): whatever serialized the JSON on their end before signing
 * it, ours must be independently re-canonicalized the same way, not
 * assumed to already match byte-for-byte. */
export async function verifyAppsProSignature(
  env: Env,
  body: AppsProWebhookBody,
  signatureHeader: string | null,
): Promise<void> {
  if (!signatureHeader) throw new AppsProSignatureError('Missing X-Signature header');
  const canonical = canonicalize(body);
  const expected = await hmacHex(env.APPSPRO_SECRET_KEY, canonical);
  if (!timingSafeEqual(expected, signatureHeader.toLowerCase())) {
    throw new AppsProSignatureError('Signature mismatch');
  }
}

/** `data.subscriberId` arrives as `"tel:8801712345678"` (AppsPro's own
 * subscriber-id format, not a raw phone number) — this is the join key
 * back to `ProfileRepository.setPhoneNumber`'s raw-digits storage. */
function phoneFromSubscriberId(subscriberId: unknown): string | null {
  if (typeof subscriberId !== 'string') return null;
  const withoutPrefix = subscriberId.startsWith('tel:') ? subscriberId.slice(4) : subscriberId;
  return withoutPrefix || null;
}

async function findUidByPhone(env: Env, phone: string): Promise<string | null> {
  const matches = await queryCollection(env, 'users', 'phoneNumber', phone);
  return matches[0]?.id ?? null;
}

/** Handles the subscription-lifecycle events that actually change paywall
 * access. AppsPro's own documentation contradicts itself on this: the
 * per-app dashboard's "Webhook Events" checklist describes
 * `subscriber.created` as firing "when user requests OTP" (i.e. before
 * anything is actually confirmed) with `subscriber.verified` as the real
 * completion event — but the dashboard's own general Docs page's "Event
 * Catalog" describes `subscriber.created` as firing on "OTP verified —
 * new subscriber registered" (i.e. IS the completion event) and doesn't
 * list `subscriber.verified` at all. Rather than bet on which first-party
 * description is the stale one, both `created` and `verified` are
 * treated as grant events here — the downside of maybe reacting to
 * `created` a little early (if the checklist's description turns out
 * right) is far smaller than the downside of never granting access at
 * all (if the docs page's description turns out right and `verified`
 * simply never fires). `reactivated` is in the docs page's Event Catalog
 * too (a previously-cancelled subscriber re-registering) and costs
 * nothing to also honor. `cancelled` revokes access.
 *
 * Everything else (inbound SMS/USSD forwarding, hosted-checkout
 * telemetry) is acknowledged with 200 and otherwise ignored — nothing in
 * this app reacts to them, and returning anything other than 2xx for an
 * event we simply don't act on would just make AppsPro retry it forever.
 */
export async function handleAppsProWebhook(env: Env, body: AppsProWebhookBody): Promise<void> {
  const { event, data } = body;

  const GRANT_EVENTS = new Set(['subscriber.created', 'subscriber.verified', 'subscriber.reactivated']);
  if (!GRANT_EVENTS.has(event) && event !== 'subscriber.cancelled') {
    return;
  }

  const phone = phoneFromSubscriberId(data.subscriberId);
  if (!phone) {
    console.error('AppsPro webhook missing/malformed subscriberId:', JSON.stringify(data));
    return;
  }

  const uid = await findUidByPhone(env, phone);
  if (!uid) {
    // A subscription exists on AppsPro's side for a phone number we don't
    // recognize — most likely the user completed checkout before this app
    // ever recorded their number (or entered a different one at checkout
    // than the one on their profile). Logged, not thrown: this is a data
    // problem to notice, not a transient error AppsPro should retry.
    console.error(`AppsPro webhook: no user found with phoneNumber "${phone}" (event ${event})`);
    return;
  }

  // `setDocument` is a full overwrite (no updateMask — see its doc
  // comment in firestoreClient.ts), so a cancel event would otherwise
  // blow away fields like `startedAt` that were only ever set once, at
  // grant time. Read first and merge, the same get-then-set idiom
  // `ApplicationRepository.setStatus` already uses client-side to
  // preserve `createdAt` across updates.
  //
  // Timestamps come back from `getDocument` as ISO strings (Firestore's
  // REST encoding, decoded plainly — see `fromFirestoreValue`), not `Date`
  // instances. `toFirestoreFields` only recognizes an actual `Date` as a
  // timestamp; passing the string straight back through would silently
  // re-store it as `stringValue` instead of `timestampValue`. Both get
  // reconstructed as `Date` here before being written again.
  const existing = (await getDocument(env, `subscriptions/${uid}`)) ?? {};
  const existingStartedAt = typeof existing.startedAt === 'string' ? new Date(existing.startedAt) : null;
  const existingRenewsAt = typeof existing.renewsAt === 'string' ? new Date(existing.renewsAt) : null;
  const now = new Date();

  if (event === 'subscriber.cancelled') {
    await setDocument(env, `subscriptions/${uid}`, {
      tier: 'paid',
      status: 'canceled',
      bdappsSubscriptionId: data.subscriberId,
      startedAt: existingStartedAt,
      renewsAt: existingRenewsAt,
      canceledAt: now,
    });
    return;
  }

  // created, verified, or reactivated — see GRANT_EVENTS above
  await setDocument(env, `subscriptions/${uid}`, {
    tier: 'paid',
    status: 'active',
    bdappsSubscriptionId: data.subscriberId,
    startedAt: existingStartedAt ?? now,
    renewsAt: existingRenewsAt,
    canceledAt: null,
  });
}
