/**
 * Bangladeshi phone number normalization + operator identification —
 * server-side mirror of `lib/core/utils/bd_phone.dart`. Kept in lockstep
 * with that file deliberately: the Worker is the one place that decides
 * whether a phone number is actually eligible (never the client's own
 * operator picker — see `bdOperatorForNormalizedPhone`'s doc comment), so
 * this logic has to exist here independently of whatever Dart already
 * validated.
 */

/** "8801XXXXXXXXX" — no "+", no leading "0". Matches the shape AppsPro's
 * own webhook/API responses use for a subscriber's phone (see
 * `appspro.ts`'s `phoneFromSubscriberId`). */
export function normalizeBdPhoneNumber(raw: string): string {
  const digits = raw.replace(/[^0-9]/g, '');
  if (digits.startsWith('880')) return digits;
  if (digits.startsWith('0')) return `880${digits.slice(1)}`;
  return `880${digits}`;
}

export type BdOperator = 'robi' | 'cirkle';

/**
 * The current BDApps business requirement (not something AppsPro's API
 * itself enforces or exposes): only Robi (018) and Cirkle (016) numbers
 * are supported. Derived purely from the phone number's own digits —
 * deliberately NOT from any "operator" field a client request might send,
 * per the standing instruction not to let a UI label stand in for
 * authoritative validation. A client's operator picker is UX only; this
 * function is what actually decides whether `/v1/subscription/otp/request`
 * proceeds.
 */
export function bdOperatorForNormalizedPhone(normalized: string): BdOperator | null {
  if (normalized.length !== 13 || !normalized.startsWith('8801')) return null;
  const operatorDigit = normalized[4];
  if (operatorDigit === '8') return 'robi';
  if (operatorDigit === '6') return 'cirkle';
  return null;
}

/** `data.subscriberId`/`subscriber_id` arrives as `"tel:8801712345678"`
 * throughout AppsPro's API (webhooks, `otp/verify`, `sdk/verify`) — this
 * is the one place that shape gets parsed, shared by `appspro.ts` (the
 * webhook path) and `subscription.ts` (the direct-API sign-in path). */
export function phoneFromSubscriberId(subscriberId: unknown): string | null {
  if (typeof subscriberId !== 'string') return null;
  const withoutPrefix = subscriberId.startsWith('tel:') ? subscriberId.slice(4) : subscriberId;
  return withoutPrefix || null;
}

/** A stable, deterministic uid for a phone-based sign-in — the same
 * number always reaches the same Firestore profile on every subsequent
 * sign-in, since a verified bdapps subscription IS the account now (see
 * `firebaseCustomToken.ts`'s doc comment). Not a hash: the normalized
 * phone number is already a stable, sufficiently-unique key, and staying
 * human-readable in the Firebase/Firestore console is more useful here
 * than an opaque digest would be. */
export function uidForPhone(normalizedPhone: string): string {
  return `bdapps_${normalizedPhone}`;
}
