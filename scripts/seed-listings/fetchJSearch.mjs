import { writeFile, mkdir } from 'node:fs/promises';

/**
 * Fetches real Bangladesh job listings from JSearch (RapidAPI) across a
 * spread of categories — not just software roles, so the feed reads like
 * a real general job board — and caches the raw responses to `.cache/`.
 *
 * Separated from `seed.mjs` deliberately: the free tier is a hard 200
 * requests/month, so fetching and writing-to-Firestore are two distinct,
 * independently-runnable steps. Iterating on the Firestore mapping
 * (`lib/mapJSearchJob.mjs`) should never cost API quota — `seed.mjs`
 * always reads from this cache, never calls JSearch itself.
 */

const QUERIES = [
  'software developer jobs in Dhaka Bangladesh',
  'marketing executive jobs in Dhaka Bangladesh',
  'accountant jobs in Bangladesh',
  'customer support jobs in Dhaka Bangladesh',
  'graphic designer jobs in Bangladesh',
];

const apiKey = process.env.JSEARCH_API_KEY;
if (!apiKey) {
  throw new Error('Set JSEARCH_API_KEY (see .env.example)');
}

await mkdir(new URL('.cache/', import.meta.url), { recursive: true });

for (const query of QUERIES) {
  const url = new URL('https://jsearch.p.rapidapi.com/search-v2');
  url.searchParams.set('query', query);
  url.searchParams.set('num_pages', '1');
  url.searchParams.set('country', 'bd');
  url.searchParams.set('date_posted', 'month');

  const res = await fetch(url, {
    headers: {
      'x-rapidapi-host': 'jsearch.p.rapidapi.com',
      'x-rapidapi-key': apiKey,
    },
  });

  if (!res.ok) {
    throw new Error(`JSearch request failed for "${query}": ${res.status} ${await res.text()}`);
  }

  const body = await res.json();
  const jobs = body?.data?.jobs ?? body?.data ?? [];
  const slug = query.replace(/[^a-z0-9]+/gi, '-').toLowerCase();
  const outPath = new URL(`.cache/${slug}.json`, import.meta.url);
  await writeFile(outPath, JSON.stringify(body, null, 2));
  console.log(`${query} -> ${jobs.length} jobs -> ${outPath.pathname}`);
}
