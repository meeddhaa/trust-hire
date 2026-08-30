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

// Jobs actually located in Bangladesh — `country=bd` scoping applies.
const BD_QUERIES = [
  'software developer jobs in Dhaka Bangladesh',
  'marketing executive jobs in Dhaka Bangladesh',
  'accountant jobs in Bangladesh',
  'customer support jobs in Dhaka Bangladesh',
  'graphic designer jobs in Bangladesh',
  'IT support jobs in Bangladesh',
  'content writer jobs in Bangladesh',
  'HR executive jobs in Bangladesh',
  'sales executive jobs in Dhaka Bangladesh',
];

// International "work from anywhere" remote roles — a real, legitimate
// category for Bangladeshi job seekers (a BD candidate genuinely can
// apply to and work these), deliberately NOT scoped to `country=bd`.
// Earlier testing (see `lib/mapJSearchJob.mjs`'s `isActuallyRemote` doc
// comment) found that adding "remote" wording to a `country=bd`-scoped
// query makes JSearch ignore that scoping anyway and return non-BD
// results — so for this set we don't fight that, we lean into it and
// drop the `country` param entirely. Spread across tech AND non-tech
// categories on purpose — remote work isn't just software roles.
const REMOTE_QUERIES = [
  'remote software developer jobs work from anywhere',
  'remote customer support jobs worldwide',
  'remote virtual assistant jobs worldwide',
  'remote content writer jobs work from home',
  'remote data entry jobs online worldwide',
  'remote graphic designer jobs worldwide',
  'remote digital marketing jobs work from anywhere',
  'remote sales representative jobs worldwide',
];

const apiKey = process.env.JSEARCH_API_KEY;
if (!apiKey) {
  throw new Error('Set JSEARCH_API_KEY (see .env.example)');
}

await mkdir(new URL('.cache/', import.meta.url), { recursive: true });

async function fetchQuery(query, { country, cachePrefix }) {
  const url = new URL('https://jsearch.p.rapidapi.com/search-v2');
  url.searchParams.set('query', query);
  url.searchParams.set('num_pages', '1');
  if (country) url.searchParams.set('country', country);
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
  const outPath = new URL(`.cache/${cachePrefix}${slug}.json`, import.meta.url);
  await writeFile(outPath, JSON.stringify(body, null, 2));
  console.log(`${query} -> ${jobs.length} jobs -> ${outPath.pathname}`);
}

for (const query of BD_QUERIES) {
  await fetchQuery(query, { country: 'bd', cachePrefix: '' });
}
for (const query of REMOTE_QUERIES) {
  await fetchQuery(query, { country: undefined, cachePrefix: 'intl-remote-' });
}
