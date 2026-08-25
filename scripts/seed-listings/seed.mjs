import { readdir, readFile } from 'node:fs/promises';
import { cert, initializeApp } from 'firebase-admin/app';
import { getFirestore } from 'firebase-admin/firestore';
import { mapJSearchJob } from './lib/mapJSearchJob.mjs';
import { SCAM_EXAMPLES } from './lib/scamExamples.mjs';

/**
 * Reads every cached JSearch response from `.cache/` (populated by
 * `npm run fetch` — never calls the API itself, see that file's doc
 * comment), maps each job to the `JobListing` Firestore shape, mixes in
 * the hand-authored scam-pattern examples, and writes the combined set to
 * Firestore's `listings` collection via `firebase-admin` (the same
 * service-account pattern used elsewhere for admin writes — the client
 * can't write this collection, see `firestore.rules`).
 */

const serviceAccountPath = process.env.FIREBASE_SERVICE_ACCOUNT_PATH;
if (!serviceAccountPath) {
  throw new Error('Set FIREBASE_SERVICE_ACCOUNT_PATH (see .env.example)');
}
const serviceAccount = JSON.parse(await readFile(serviceAccountPath, 'utf8'));
initializeApp({ credential: cert(serviceAccount) });
const db = getFirestore();

async function loadCachedJobs() {
  const cacheDir = new URL('.cache/', import.meta.url);
  const files = (await readdir(cacheDir)).filter((f) => f.endsWith('.json'));
  if (files.length === 0) {
    throw new Error('.cache/ is empty — run `npm run fetch` first');
  }

  const seen = new Map();
  for (const file of files) {
    const body = JSON.parse(await readFile(new URL(file, cacheDir), 'utf8'));
    const jobs = body?.data?.jobs ?? body?.data ?? [];
    for (const job of jobs) {
      if (job.job_id) seen.set(job.job_id, job); // dedupe across category files
    }
  }
  return [...seen.values()];
}

const rawJobs = await loadCachedJobs();
const realListings = rawJobs.map(mapJSearchJob);
const allListings = [...realListings, ...SCAM_EXAMPLES];

const batch = db.batch();
for (const listing of allListings) {
  const { id, ...fields } = listing;
  batch.set(db.collection('listings').doc(id), fields);
}
await batch.commit();

console.log(`Seeded ${realListings.length} real listings + ${SCAM_EXAMPLES.length} curated scam examples`);
console.log(`Total: ${allListings.length} documents written to listings/`);
process.exit(0);
