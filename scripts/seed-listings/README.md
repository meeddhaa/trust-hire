# seed-listings

Populates Firestore's `listings` collection (step 5 of the build order):
real Bangladesh job postings pulled from the [JSearch API](https://rapidapi.com/letscrape-6bRBa3QguO5/api/jsearch)
(RapidAPI), plus a handful of hand-authored scam-pattern examples the
brief explicitly asks for — JSearch is a legitimate aggregator and will
never itself return a fraudulent posting to seed the risk detector with.

See `docs/ARCHITECTURE.md` → "Decision: JSearch for real listings" for
why this lives here (a Node script, not `lib/data/seed/` as originally
planned in Dart) and what was actually verified about JSearch's Bangladesh
coverage before committing to this approach.

## Why two separate steps

```
npm run fetch   # calls JSearch, writes raw responses to .cache/
npm run seed    # reads .cache/, maps + writes to Firestore — no API call
```

JSearch's free tier is a **hard 200 requests/month** cap (confirmed live:
each search query = 1 request). `fetch` is the only step that spends
quota, so it's meant to be run deliberately — iterating on the Firestore
mapping in `lib/mapJSearchJob.mjs`, or re-running the write after fixing a
bug, never needs a second `fetch`. `.cache/` is gitignored (regenerable,
and redistributing raw third-party API responses in version control isn't
something to do casually) — everything downstream is derived from it.

## Setup

```bash
npm install
cp .env.example .env
# fill in JSEARCH_API_KEY (fetch only) and FIREBASE_SERVICE_ACCOUNT_PATH
```

Service account key: Firebase Console → Project Settings → Service
Accounts → "Generate new private key". Same one used for the Worker
(`worker/README.md`) — reuse the file, don't generate a new one per tool.

## Run

```bash
npm run fetch   # only when you actually want fresh listings; costs quota
npm run seed    # safe to re-run anytime — idempotent (see below)
node --env-file=.env verify.mjs   # spot-check counts + a sample doc after seeding
```

## Notes on the data

- **Categories fetched**: software developer, marketing executive,
  accountant, customer support, graphic designer — all scoped to
  `country=bd` — so the feed reads like a general job board, not just a
  tech-jobs demo. Add more queries to `fetchJSearch.mjs`'s `QUERIES` array
  if you want more variety; each additional query costs one more request.
- **What JSearch doesn't provide**: structured salary (always came back
  null in testing — `job_min_salary`/`job_max_salary`) and a structured
  skills list (`job_highlights` came back empty for every BD result
  tested). `lib/skillKeywords.mjs` extracts `requiredSkills` by scanning
  `job_description` against a keyword dictionary instead — good enough
  for card display and the scam rule engine's salary/seniority check; the
  match-gap LLM call always gets the full description text regardless.
- **Idempotent**: each listing's Firestore doc ID is a hash of JSearch's
  own `job_id` (`lib/mapJSearchJob.mjs`), so re-running `seed` overwrites
  the same documents rather than duplicating them.
- **Scam examples** (`lib/scamExamples.mjs`): five listings, deliberately
  spread across the badge spectrum (not every example maxes out all five
  rule signals) so the demo shows caution *and* high-risk, not just one
  extreme. Company names are invented; the patterns themselves (upfront
  "training fees," WhatsApp-only recruiting, unrealistic no-experience
  pay, artificial urgency) are the well-documented generic tactics named
  in the brief, not copied from any real posting.
