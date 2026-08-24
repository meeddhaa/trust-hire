# trusthire-ai-relay

Cloudflare Worker: the Gemini relay named in the brief. Holds the Gemini
API key server-side (never in the Flutter client), verifies the caller's
Firebase identity, rate-limits per user, computes the deterministic
scam-rule score server-side for the shared `scamAssessments` cache, calls
Gemini for structured JSON reasoning, and writes results back to
Firestore.

**Deployed and verified end-to-end** at
`https://trusthire-ai-relay.nafisa-notesapp.workers.dev` — both endpoints
tested live against real Firebase Auth tokens, real Firestore reads/writes,
and real Gemini calls (clean listing → `verifiedLeaning` with grounded
reasoning; a listing seeded with all five scam signals → `highRisk` with
per-signal reasoning; a match call → correctly matched/gap skills in the
brief's exact "Matched: X, Y. Gap: Z" format plus a concrete roadmap).
Cache-hit behavior confirmed (identical `computedAt` on repeat calls, no
second Gemini spend). All test data and the throwaway test user were
deleted afterward — see git history on this file for the two real bugs
that first pass caught.

See `docs/ARCHITECTURE.md` → "Data flow: match + scam assessment" for how
this fits into the rest of the app, and `docs/DATA_MODELS.md` for the
Firestore schema this reads and writes.

## Endpoints

Both require `Authorization: Bearer <Firebase ID token>` and reject
anything else with `401` — the token is verified against Firebase's public
keys in-Worker (`src/auth.ts`), not just trusted at face value, since the
`uid` it yields is what gets rate-limited and written to Firestore.

### `POST /v1/match`
```json
{ "listingId": "abc123" }
```
Looks up the caller's profile (`users/{uid}`) and the listing
(`listings/{listingId}`), returns a cached `matchResults/{uid}_{listingId}`
if one exists for the current prompt version, otherwise calls Gemini and
caches the result. `404` if the listing or profile doesn't exist.

### `POST /v1/scam-assessment`
```json
{ "listingId": "abc123" }
```
Recomputes the five rule-based scam flags server-side from the listing
(never trusts client-supplied flags — this result is cached once and
shared by every user), returns a cached `scamAssessments/{listingId}` if
current, otherwise calls Gemini for the reasoning text and caches the full
result.

Both: `429` if the caller has hit `RATE_LIMIT_PER_USER_PER_DAY` for today
(only actual Gemini calls count against this — a cache hit is free).

## One-time setup

### 1. Create the KV namespace (rate limiting)
```bash
npx wrangler kv namespace create RATE_LIMIT_KV
```
Paste the returned `id` into `wrangler.jsonc`'s `kv_namespaces[0].id`,
replacing `REPLACE_WITH_KV_NAMESPACE_ID`.

### 2. Create a service account for Firestore writes
The Worker authenticates to Firestore as a Google service account (not the
Firebase Admin SDK, which assumes Node — see `src/firestoreClient.ts`).

1. https://console.firebase.google.com/project/trusthire-bdapps/settings/serviceaccounts/adminsdk
2. "Generate new private key" → downloads a JSON file. **Do not commit it.**
3. From that JSON, you need `client_email` and `private_key` for the
   secrets below.

### 3. Set secrets
```bash
npx wrangler secret put GEMINI_API_KEY
npx wrangler secret put FIREBASE_CLIENT_EMAIL
npx wrangler secret put FIREBASE_PRIVATE_KEY   # paste the full PEM, including
                                                # the BEGIN/END lines and newlines
```
Get a Gemini API key at https://aistudio.google.com/apikey.

For local dev, copy `.dev.vars.example` to `.dev.vars` (gitignored) and
fill in the same three values instead of using `wrangler secret put`.

### 4. Deploy
```bash
npm install
npm run deploy
```
Note the deployed URL — that's what `core/network/` in the Flutter app
points at (currently `https://trusthire-ai-relay.nafisa-notesapp.workers.dev`).

## Local development note

`wrangler dev` and the "runtime types" step of `wrangler types` both shell
out to the actual Workers runtime (`workerd`), which requires **macOS
13.5+ or Linux (glibc 2.35+)**. The primary dev machine for this project is
on macOS 12.6.0, so neither works here — `worker-configuration.d.ts` was
generated from wrangler's project-types output by hand for this reason
(see the comment at the top of that file) and `wrangler deploy` (which
runs the build on Cloudflare's servers, not locally) is how this Worker
gets tested end-to-end. If you're on a newer macOS or Linux, both should
work normally.

## Testing

```bash
npm test
```
Runs `test/scamRules.test.ts` and `test/auth.test.ts` — plain Vitest, no
Workers runtime needed: `scamRules.ts` is pure logic (regex + arithmetic),
and `crypto.subtle`/`atob`/`TextDecoder` (what `auth.ts` needs) are all
available under plain Node too. `firestoreClient.ts`'s service-account
flow and `gemini.ts`'s fetch call weren't unit-tested this way (they're
thin wrappers around real network calls, better suited to an integration
test) — instead they were verified against the live deployment, see
"Deployed and verified end-to-end" above. `KVNamespace`-typed code
(`rateLimiter.ts`) would need `@cloudflare/vitest-pool-workers` (already a
devDependency) wired up via `defineWorkersConfig` in `vitest.config.ts` —
deferred until this runs on a supported OS or in CI.

## Manual smoke test

```bash
# Should 401 — no Authorization header
curl -X POST https://trusthire-ai-relay.nafisa-notesapp.workers.dev/v1/match \
  -H "Content-Type: application/json" -d '{"listingId":"test"}'

# With a real Firebase ID token (e.g. copied from the Flutter app's
# FirebaseAuth.instance.currentUser?.getIdToken() during a debug session):
curl -X POST https://trusthire-ai-relay.nafisa-notesapp.workers.dev/v1/match \
  -H "Authorization: Bearer <ID_TOKEN>" \
  -H "Content-Type: application/json" -d '{"listingId":"<a real listing id>"}'
```
