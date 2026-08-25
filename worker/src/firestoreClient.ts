/**
 * Minimal Firestore REST client, authenticated as a Google service
 * account — not the Firebase Admin SDK, which assumes a Node server and
 * doesn't run in a Workers isolate.
 *
 * Per `firestore.rules`, `matchResults`/`scamAssessments` are
 * client-write-`false`: only Admin-equivalent credentials can write them.
 * The service account's OAuth token *is* that Admin-equivalent credential
 * here — it bypasses security rules entirely, which is exactly why the
 * Worker verifies the caller's Firebase ID token itself (see auth.ts)
 * before ever reaching this client.
 *
 * Token fetch/cache lives in `serviceAccountAuth.ts`, shared with
 * `storageClient.ts`.
 */

import { getServiceAccountAccessToken } from './serviceAccountAuth';

interface Env {
  FIREBASE_PROJECT_ID: string;
  FIREBASE_CLIENT_EMAIL: string;
  FIREBASE_PRIVATE_KEY: string;
}

// --- Firestore's typed-value REST encoding, both directions -------------

type FirestoreValue =
  | { stringValue: string }
  | { integerValue: string }
  | { doubleValue: number }
  | { booleanValue: boolean }
  | { nullValue: null }
  | { timestampValue: string }
  | { arrayValue: { values?: FirestoreValue[] } }
  | { mapValue: { fields?: Record<string, FirestoreValue> } };

function toFirestoreValue(value: unknown): FirestoreValue {
  if (value === null || value === undefined) return { nullValue: null };
  if (typeof value === 'string') return { stringValue: value };
  if (typeof value === 'boolean') return { booleanValue: value };
  if (typeof value === 'number') {
    return Number.isInteger(value) ? { integerValue: String(value) } : { doubleValue: value };
  }
  if (value instanceof Date) return { timestampValue: value.toISOString() };
  if (Array.isArray(value)) return { arrayValue: { values: value.map(toFirestoreValue) } };
  if (typeof value === 'object') {
    return { mapValue: { fields: toFirestoreFields(value as Record<string, unknown>) } };
  }
  throw new Error(`Cannot encode value for Firestore: ${JSON.stringify(value)}`);
}

export function toFirestoreFields(data: Record<string, unknown>): Record<string, FirestoreValue> {
  const fields: Record<string, FirestoreValue> = {};
  for (const [key, value] of Object.entries(data)) {
    fields[key] = toFirestoreValue(value);
  }
  return fields;
}

function fromFirestoreValue(value: FirestoreValue): unknown {
  if ('stringValue' in value) return value.stringValue;
  if ('integerValue' in value) return Number.parseInt(value.integerValue, 10);
  if ('doubleValue' in value) return value.doubleValue;
  if ('booleanValue' in value) return value.booleanValue;
  if ('nullValue' in value) return null;
  if ('timestampValue' in value) return value.timestampValue;
  if ('arrayValue' in value) return (value.arrayValue.values ?? []).map(fromFirestoreValue);
  if ('mapValue' in value) return fromFirestoreFields(value.mapValue.fields ?? {});
  return null;
}

export function fromFirestoreFields(fields: Record<string, FirestoreValue>): Record<string, unknown> {
  const data: Record<string, unknown> = {};
  for (const [key, value] of Object.entries(fields)) {
    data[key] = fromFirestoreValue(value);
  }
  return data;
}

// --- Document operations -------------------------------------------------

function documentUrl(env: Env, path: string): string {
  return `https://firestore.googleapis.com/v1/projects/${env.FIREBASE_PROJECT_ID}/databases/(default)/documents/${path}`;
}

/** Reads one document by path (e.g. `listings/abc123`). Returns `null` if
 * it doesn't exist — never throws for a 404, since "not found" is an
 * expected, callers-must-handle outcome here, not a server error. */
export async function getDocument(env: Env, path: string): Promise<Record<string, unknown> | null> {
  const token = await getServiceAccountAccessToken(env);
  const res = await fetch(documentUrl(env, path), {
    headers: { Authorization: `Bearer ${token}` },
  });
  if (res.status === 404) return null;
  if (!res.ok) throw new Error(`Firestore read failed (${res.status}): ${await res.text()}`);
  const body = await res.json<{ fields?: Record<string, FirestoreValue> }>();
  return fromFirestoreFields(body.fields ?? {});
}

/** Fully replaces a document's fields (no `updateMask`, so this is a
 * complete overwrite) — safe here because every write in this Worker
 * always constructs the full `MatchResult`/`ScamAssessment` shape, never a
 * partial patch. */
export async function setDocument(env: Env, path: string, data: Record<string, unknown>): Promise<void> {
  const token = await getServiceAccountAccessToken(env);
  const res = await fetch(documentUrl(env, path), {
    method: 'PATCH',
    headers: {
      Authorization: `Bearer ${token}`,
      'Content-Type': 'application/json',
    },
    body: JSON.stringify({ fields: toFirestoreFields(data) }),
  });
  if (!res.ok) throw new Error(`Firestore write failed (${res.status}): ${await res.text()}`);
}
