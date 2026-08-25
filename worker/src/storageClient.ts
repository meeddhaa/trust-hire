/**
 * Minimal Firebase/Cloud Storage REST client — read-only, just enough to
 * fetch an uploaded resume PDF for the resume-tailoring endpoint.
 * Authenticated as the same service account as `firestoreClient.ts` (see
 * `serviceAccountAuth.ts`), which is why `storage.rules`' owner-only
 * client rule doesn't apply here — this is the server reading on the
 * verified caller's behalf, the same trust model as the Firestore client.
 */

import { getServiceAccountAccessToken } from './serviceAccountAuth';

interface Env {
  FIREBASE_STORAGE_BUCKET: string;
  FIREBASE_CLIENT_EMAIL: string;
  FIREBASE_PRIVATE_KEY: string;
}

function base64Encode(bytes: ArrayBuffer): string {
  const arr = new Uint8Array(bytes);
  let binary = '';
  // Chunked to avoid blowing the call stack on String.fromCharCode(...arr)
  // for a several-MB PDF.
  const chunkSize = 8192;
  for (let i = 0; i < arr.length; i += chunkSize) {
    binary += String.fromCharCode(...arr.subarray(i, i + chunkSize));
  }
  return btoa(binary);
}

/** Returns the object's bytes as base64, or `null` if it doesn't exist —
 * "no resume uploaded" is an expected, caller-must-handle outcome, not a
 * server error. */
export async function getStorageObjectBase64(env: Env, objectPath: string): Promise<string | null> {
  const token = await getServiceAccountAccessToken(env);
  const encodedPath = encodeURIComponent(objectPath);
  const url = `https://storage.googleapis.com/storage/v1/b/${env.FIREBASE_STORAGE_BUCKET}/o/${encodedPath}?alt=media`;

  const res = await fetch(url, { headers: { Authorization: `Bearer ${token}` } });
  if (res.status === 404) return null;
  if (!res.ok) throw new Error(`Storage read failed (${res.status}): ${await res.text()}`);

  return base64Encode(await res.arrayBuffer());
}
