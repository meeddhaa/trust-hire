import { readFile } from 'node:fs/promises';
import { cert, initializeApp } from 'firebase-admin/app';
import { getFirestore } from 'firebase-admin/firestore';

const serviceAccount = JSON.parse(await readFile(process.env.FIREBASE_SERVICE_ACCOUNT_PATH, 'utf8'));
initializeApp({ credential: cert(serviceAccount) });
const db = getFirestore();

const snapshot = await db.collection('listings').get();
console.log(`Total documents in listings/: ${snapshot.size}`);

let missingTitle = 0;
let missingDescription = 0;
let scamExamples = 0;
let realListings = 0;

for (const doc of snapshot.docs) {
  const d = doc.data();
  if (!d.title) missingTitle++;
  if (!d.description) missingDescription++;
  if (doc.id.startsWith('scam-example-')) scamExamples++;
  else realListings++;
}

console.log(`Real listings: ${realListings}, scam examples: ${scamExamples}`);
console.log(`Missing title: ${missingTitle}, missing description: ${missingDescription}`);

console.log('\nSample real listing:');
const sample = snapshot.docs.find((d) => !d.id.startsWith('scam-example-'));
console.log(JSON.stringify({ id: sample.id, ...sample.data() }, null, 2).slice(0, 1200));

console.log('\nSample scam example:');
const scamSample = snapshot.docs.find((d) => d.id.startsWith('scam-example-'));
console.log(JSON.stringify({ id: scamSample.id, ...scamSample.data() }, null, 2).slice(0, 800));

process.exit(0);
