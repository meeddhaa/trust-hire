# Architecture

## Folder structure

```
lib/
  main.dart                     Entry point: Firebase init, ProviderScope, App
  app.dart                      MaterialApp.router (ConsumerWidget, watches goRouterProvider)

  core/
    theme/                      Color system, type scale, motion tokens ("Northern Ledger")
    router/                     app_router.dart (goRouterProvider: route table + redirect
                                 guards for auth/onboarding), splash_screen.dart
    providers/                  Cross-feature Riverpod DI: repository_providers.dart
                                 (one Provider per repository/service), session_providers.dart
                                 (currentUidProvider, currentProfileProvider,
                                 currentSubscriptionProvider) — added beyond the original
                                 per-feature-only plan once 3+ features needed the same
                                 profile/subscription state; see "Why core/providers/" below.
                                 theme_mode_provider.dart: persisted light/dark/system choice
    constants/                  Firestore collection names, Worker base URL + model versions
    network/                    api_client.dart — generic JSON POST + status-to-Failure mapping,
                                 shared by worker_api_service.dart now and bdapps_api_service.dart
                                 in step 7
    errors/                     failure.dart — Failure hierarchy, implements Exception so
                                 repositories `throw` it and AsyncNotifier/FutureProvider
                                 capture it into AsyncValue.error automatically
    utils/                      firestore_codec.dart (Timestamp<->DateTime)

  data/
    models/                     UserProfile, JobListing, MatchResult, ScamAssessment,
                                 ScamRuleFlags, Subscription
    repositories/                ProfileRepository, ListingsRepository, MatchRepository,
                                 ScamRepository, SubscriptionRepository — Match/Scam check a
                                 direct Firestore read first, only call the Worker on a miss
                                 or stale modelVersion (see "Data flow" below)
    services/                    - firebase_auth_service.dart  (email + Google sign-in)
                                 - worker_api_service.dart      (Gemini relay calls)
                                 - scam_rule_engine.dart        (client-side deterministic scorer)
                                 - bdapps_api_service.dart      (step 7 — not built yet)
                                 No separate firestore_service.dart: repositories call
                                 `FirebaseFirestore.instance` directly — cloud_firestore's own
                                 API is already a clean-enough abstraction at this project's
                                 size; adding another wrapper layer would be indirection with
                                 no payoff (see pubspec's own "avoid overengineering" note)
    seed/                       Empty — the actual seed tooling lives at
                                 `scripts/seed-listings/` (Node, not Dart) instead; see
                                 "Decision: JSearch for real listings" below for why

  features/                     One folder per screen/flow. Each has:
                                   presentation/  screens + feature-local widgets
                                   providers/     Riverpod providers/notifiers for that flow
    auth/                       Sign in / sign up (email + Google) — added beyond the
                                 original plan, which didn't list a dedicated auth feature;
                                 kept separate from onboarding since "authenticate" and
                                 "build a profile" are genuinely different concerns and
                                 the router needs auth state independent of profile state
    onboarding/                 Profile build (skills, experience — typed, no resume upload;
                                 see "Storage" decision below)
    listings/                   Feed: scrollable, staggered-entrance list of JobListingCards.
                                 Cards show the trust badge only (instant, free, client-side) —
                                 not a match score, which needs a Worker/Gemini call; showing
                                 that on every card would mean firing it on every feed scroll,
                                 exactly the quota-burning the brief warns against for scam
                                 scoring. The real match score is this build's centerpiece one
                                 screen deeper, in listing_detail, computed once and cached.
    listing_detail/             Match breakdown, trust badge + reasoning, in-app WebView to
                                 source posting. Free tier: match % + trust badge + rule flags
                                 (deterministic, cheap, shown regardless of tier). Paid tier
                                 adds: gap/matched skills, upskilling roadmap, LLM scam
                                 reasoning paragraph — gated by `currentSubscriptionProvider`
                                 in the UI layer only, per the data models' own design
    paywall/                    Tier comparison + "Subscribe via bdapps" — real, designed UI;
                                 the actual bdapps checkout is step 7, so tapping Subscribe
                                 today explains that honestly instead of faking a charge
    subscription/               Shows real subscription state (always free today, since
                                 nothing writes paid until step 7); Unsubscribe is present
                                 but disabled until step 7 wires the real bdapps call
    profile/                    View profile (bio, skills, experience) + gear icon to Settings.
                                 Editing beyond what onboarding collects is a natural
                                 follow-up once this and paywall/subscription are both settled
    settings/                   Appearance (light/dark/system), resume upload/status +
                                 template guide, manage subscription, sign out — see
                                 "Decision: Settings, separate from Profile" below

  shared/
    widgets/                    match_score_dial.dart, trust_badge_chip.dart (promoted from
                                 the design-direction preview once screens needed them),
                                 empty_state.dart, expandable_section.dart (accordion for the
                                 gap breakdown — custom-built, not ExpansionTile, so the
                                 chevron/spacing matches "Editorial Trust" exactly)
    animations/                 Not yet needed as a separate layer — the motion so far is
                                 short enough to write inline with flutter_animate at each
                                 use site (AppMotion tokens keep it consistent); revisit if a
                                 reveal sequence gets reused identically across 3+ places

test/                           Mirrors lib/ for unit + widget tests. Firebase-backed
                                 providers (auth state, and anything downstream of it,
                                 including the router) need a Firebase test harness this
                                 project doesn't have set up yet, so current coverage is
                                 scoped to what's testable without one: scam_rule_engine_test.dart
                                 (mirrors worker/test/scamRules.test.ts) and a SplashScreen
                                 smoke test. Widening this is a good next investment once the
                                 screens themselves stop changing shape.
worker/                         Cloudflare Worker (Gemini relay, rate limiting, scam scorer) —
                                 deployed, see worker/README.md
scripts/seed-listings/          Node script: real BD listings from JSearch + curated scam
                                 examples -> Firestore. See scripts/seed-listings/README.md
                                 and "Decision: JSearch for real listings" below.
web_landing/                    Responsive static landing page (subscription info, bdapps req.)
                                 — not built yet
docs/                           This file, schema notes, decision log
```

## Why `core/providers/`

The original plan put providers only under each feature's own `providers/`
folder. That held up until `listing_detail` (free/paid gating),
`onboarding` (the redirect-away-once-complete check), `profile`, and
`paywall`/`subscription` all needed the *same* live profile and
subscription state. Four features re-deriving the same Firestore stream
independently would mean four places to keep in sync, and StreamProviders
aren't naturally "owned" by any one feature when the router itself also
needs to read them synchronously for redirect guards. `core/providers/`
holds exactly two kinds of thing: DI wiring for repositories/services
(`repository_providers.dart`) and this cross-feature session state
(`session_providers.dart`) — nothing feature-specific has moved there.

## Why this shape

- **Feature-first, not layer-first at the top level.** Six screens is small
  enough that a `presentation/blocs/data` split per layer would mean jumping
  between three folders to touch one flow. Grouping by feature keeps related
  code together; `data/` stays layer-first underneath because models and
  repositories are genuinely shared across features (e.g. `JobListing` is
  read by `listings`, `listing_detail`, and `paywall`).
- **Repositories, not direct Firestore/HTTP calls in providers.** Keeps
  Firestore query shapes and Worker request/response parsing out of UI-facing
  code, and gives us a seam to point at fake data in widget tests without a
  live Firebase project.
- **`scam_rule_engine.dart` lives in `data/services/`, not the Worker.**
  Per the brief, the deterministic score must be free and instant on every
  listing view; running it client-side means feed scrolling never blocks on
  a network round-trip just to show a preliminary badge. The Worker adds the
  LLM's plain-language reasoning on top, and only gets called when a user
  opens a listing detail (not on every feed scroll).

## State management: Riverpod

Chosen over:
- **Bloc/Cubit** — more ceremony (events, states, boilerplate per
  feature) than six screens with a few async data sources justifies.
- **Provider (vanilla)** — weaker support for `family` providers, which we
  need for per-listing async state (match result and scam assessment keyed
  by listing ID, cached so re-opening a listing doesn't re-call the LLM).
- **Riverpod** gives compile-time-safe DI, `AsyncValue` for loading/error/data
  states out of the box (maps directly to the loading/empty/error states the
  brief asks us to design carefully), and `.family`/`.autoDispose` for
  per-listing caching without hand-rolled cache maps.

## Routing: go_router

Declarative routes so paywall and listing-detail can be pushed as distinct
routes (needed for the in-app WebView back stack and for a clean deep link
into a specific listing later), with redirect-based guards for
"not signed in → sign-in", "signed in but not onboarded → onboarding", and
"onboarded, at sign-in/onboarding/'/' → listings feed".

Built as `goRouterProvider` (a Riverpod `Provider<GoRouter>`), not a
top-level `final` — `redirect` needs to read live auth/profile state
synchronously, which only works if it has a `ref` in scope. A single
`GoRouter` instance stays alive across auth changes (recreating it on
every sign-in would reset the whole nav stack); a `ChangeNotifier` bridges
`ref.listen` on `authStateProvider`/`currentProfileProvider` to
`GoRouter`'s `refreshListenable`, which is what makes it re-run `redirect`
after either changes. See `core/router/app_router.dart`.

Paid-action gating (free user hitting a paid-only action) turned out not
to need a router guard: `listing_detail` just conditionally renders the
gap-breakdown/roadmap/reasoning sections based on
`currentSubscriptionProvider`, with an inline "Upgrade" prompt in place of
the locked content — simpler than intercepting navigation, and it's
exactly the same pattern `MatchResult`/`ScamAssessment` already use
(fetch the full object regardless of tier, gate what renders).

## Data flow: match + scam assessment

1. Feed loads `JobListing`s from Firestore (`ListingsRepository`).
2. On card render: `scam_rule_engine.dart` computes a deterministic
   `ScamRuleFlags` score client-side, instantly, no network call.
3. On listing open: `MatchRepository`/`ScamRepository` check Firestore for a
   cached `MatchResult`/`ScamAssessment` for (user, listing). If absent, they
   call the Cloudflare Worker, which holds the Gemini key server-side, applies
   per-user rate limiting, and returns structured JSON only. The result is
   cached back to Firestore so reopening the same listing doesn't re-spend
   API quota.
4. Free-tier users see match % + trust badge (derived from the same
   response, gated in the UI layer). Paid users see the full parsed object:
   gap skills, reasoning string, upskilling roadmap, full scam reasoning.

Full model shapes and Firestore collection schema are specced in
[docs/DATA_MODELS.md](DATA_MODELS.md).

## Visual direction: Northern Ledger (supersedes Editorial Trust)

The original confirmed direction was "Editorial Trust": warm paper/ink
base, single burnt-amber accent, Fraunces serif for score numerals.
Replaced after on-device testing — the person actually using the app on
their phone wanted a different palette (a cooler, more precise feel)
plus a light/dark/system mode toggle, which the warm/paper-vs-ink binary
wasn't built around. Three concrete alternative directions were proposed
(not just "redesign it" guessed at); "Northern Ledger" was chosen.

Cool slate/graphite base, single deep indigo-violet accent (`#5B5FEF`) —
still not blue or green, so it doesn't land on the fintech cliché the
brief calls out, just from the violet side rather than the warm side.
The verdict scale (slate-teal / amber / brick, kept *separate* from the
brand accent so trust badges/match scores read as data, not brand
decoration) is unchanged — it was never the part that needed to change.
Type pairing (Fraunces serif for score numerals/verdict headlines,
Manrope grotesk for everything else) and motion language (radial arc
count-up, hold-then-stamp badge reveal, accordion gap breakdown,
staggered feed entrance) are both also unchanged — only the color
values moved.

Implemented in `lib/core/theme/` (`app_colors.dart` — light/dark field
names renamed `paper*`/`ink*` → `ledger*`/`graphite*` to match the new
identity, not left stale; `app_typography.dart`, `app_motion.dart`,
`risk_colors.dart`, `app_theme.dart`). Appearance mode (light/dark/system)
is now a user-facing setting, not a fixed `ThemeMode.system` — see
`core/providers/theme_mode_provider.dart`, persisted via
`shared_preferences` and exposed in the new Settings screen below.

## Decision: Settings, separate from Profile

Originally, sign-out and "manage subscription" lived directly on the
Profile screen (see the now-superseded description in `## Status`
below). Split out once appearance mode and resume management needed a
home too: Profile now shows only "who you are" (bio, skills,
experience); Settings (`/settings`, reached via a gear icon on Profile)
holds "how the app behaves for you" — appearance, resume upload/status,
manage subscription, sign out.

## Decision: resume storage, twice reconsidered

Three rounds on where a resume actually lives, each forced by a real
constraint hit along the way, not preference:

**Round 1 — skip it.** Firebase requires the **Blaze** (pay-as-you-go)
plan to use Storage at all, even at zero usage — Spark doesn't support
it. Decided against enabling it: onboarding collected skills as typed
input instead of a parsed resume, `UserProfile.resumeStoragePath` left in
the model, nullable and unused, in case this got revisited.

**Round 2 — Firebase Storage, revisited.** After using the app, real
resume-based matching (not just typed skill chips) was specifically
asked for, plus an actual Gemini-powered resume-tailoring feature per
listing — worth the Blaze upgrade for. Built: Storage upload/delete via
`firebase_storage`, and a Worker endpoint that fetched the PDF from Cloud
Storage (a GCS REST client, `storageClient.ts`, reading with an extended
service-account scope) and sent it to Gemini as inline document data —
no separate text-extraction step, Gemini reads PDF content natively.

**Round 3 — no billing card exists, full stop.** Blaze couldn't actually
be enabled (no card to put on file). Cloudflare R2 was the next
candidate — already have a working Worker, R2 has a genuine free tier —
but checking its own console enable flow live showed it *also* requires
a payment method on file for activation (same "$0 at this usage level,
card required anyway" pattern as Blaze). With literally no card
available for either, landed on the one option needing zero billing
setup anywhere: **the resume PDF, base64-encoded, stored as a field
directly on the `users/{uid}` Firestore document** — Firestore's free
Spark tier has never required a card (confirmed the hard way: everything
in this app has run on it all along). `UserProfile.resumeStoragePath`
became `resumeBase64`; `firebase_storage` dependency, `storageClient.ts`,
and the extended `serviceAccountAuth.ts` Storage scope were all removed
— the Worker now reads the resume off the same Firestore profile fetch
it already does for match/job-coach, no second client needed at all.

Real constraint this adds: Firestore caps a document at 1MiB, and base64
inflates raw bytes by ~4/3, so the upload picker enforces a **700KB raw
PDF cap** (`resume_screen.dart`) — generous for a text-based resume,
tight for anything image-heavy. `storage.rules` and the R2 exploration
are dead ends now, not deferred-for-later — left in git history, not
actively maintained.

**How the PDF still reaches Gemini natively**: unchanged from Round 2 —
sent as inline document data (`gemini.ts`'s `InlineFile` parts, now
built from the Firestore-stored base64 directly), no PDF-parsing library,
no text-extraction step that could silently mis-read a resume's layout.

**Why resume-tailoring isn't cached** (unlike `MatchResult`/`ScamAssessment`):
a resume can change anytime and this is a lower-traffic, user-triggered
action (a button, not eager on page load) — caching would risk serving
stale advice against an old resume for a marginal quota saving. It still
counts against the same per-user daily rate limit as match/scam calls.

## Decision: JSearch for real listings, not a hand-written seed set

The brief's original plan (and the initial version of this doc) had the
user supplying curated real BD listings by hand — the standard "I'll
supply these" pattern for a bootcamp demo. Before building that,
research turned up: no free job API has confirmed Bangladesh coverage.
[Adzuna](https://developer.adzuna.com/) covers ~20 markets, none of them
Bangladesh. No Bangladesh job board (bdjobs.com etc.) exposes a public
API. [JSearch](https://www.openwebninja.com/api/jsearch) (RapidAPI,
aggregates Google for Jobs/LinkedIn/Indeed) was the one live option,
with an unconfirmed-until-tested free tier.

Tested live before committing to it (not assumed): `country=bd` queries
against real BD roles (software, marketing, accounting, customer
support, design) returned real, verifiably-Bangladeshi results —
Therap (BD) Ltd., BJIT, nextjobz, Sheba.xyz, real `.com`/`.com.bd`
employer domains, real LinkedIn apply links — confirmed by inspecting
actual response payloads, not by trusting the API's own claims. Two
real gaps surfaced in that same testing, both handled rather than
ignored: JSearch never returns structured salary or a structured skills
list (`lib/skillKeywords.mjs` extracts skills from the description text
instead), and being a legitimate aggregator, it will **never** return a
fraudulent listing — so the brief's explicit ask for "realistic
scam-pattern examples" still needed hand-authoring regardless
(`lib/scamExamples.mjs`, 4 examples spread across the caution/high-risk
badge range, not all maxed out).

One real API-integration wrinkle, also hit and fixed rather than
guessed around: the documented endpoint path (`/search`, per multiple
external sources) 404'd — RapidAPI's gateway returns the same generic
"endpoint does not exist" message whether a key lacks a subscription or
the path is simply wrong, which made this genuinely ambiguous until
pulling the real path from RapidAPI's own code-snippet panel:
**`/search-v2`**, undocumented in the sources checked beforehand.

This is a Node script (`scripts/seed-listings/`), not Dart under
`lib/data/seed/` as originally planned — `cloud_firestore` is a Flutter
plugin (platform channels), it doesn't run as a standalone script, and
`firebase-admin` (Node) was already the proven pattern from setting up
the Worker. Two-step by design (`npm run fetch` then `npm run seed`,
see that directory's README) because JSearch's free tier is a hard 200
requests/month — fetching and writing to Firestore are separate so
iterating on the Firestore mapping never costs API quota.

## Decision: platform expansion beyond the original brief

After using the app on-device, real feedback pushed this well past the
original bdapps brief's scope: a full navigation restructure, application
tracking, saved jobs, multi-touchpoint AI reframed as one "Job Coach,"
account deletion, and ATS resume templates. **Explicitly sequenced ahead
of the brief's still-missing hard requirements** (web landing page, bdapps
integration) — a deliberate, confirmed choice, not scope creep that
snuck in. Flagged clearly before building any of it; logged here so the
tradeoff is on the record, not just in chat history.

### Navigation: drawer + bottom-nav shell

Previously: icons bolted onto individual app bars (a person icon on the
feed, a gear icon on Profile) as each screen was built, with no single
navigational structure. Restructured into two clearly separated layers,
per explicit feedback that this had gotten messy:

- **Primary product surface** — Jobs / Applications / Saved / Job Coach /
  Profile as bottom-nav tabs (`core/router/main_shell.dart`), built on
  go_router's `StatefulShellRoute.indexedStack` so each tab keeps its own
  navigation stack (pushing a listing detail from Jobs doesn't disturb
  Applications' scroll position).
- **Account management** — Resume, Settings, Subscription, Sign out, in a
  drawer (`core/router/app_drawer.dart`) reached from a hamburger icon on
  every tab. Deliberately doesn't repeat Profile (already its own tab) —
  the same destination reachable two confusing ways was the exact problem
  being fixed.

Real bug this surfaced, fixed the same way as the earlier
`segmentedButtonTheme` fix: `NavigationBar`'s default selected-tab
indicator also reads `colorScheme.secondaryContainer` — without an
explicit `navigationBarTheme`, the active bottom-nav tab rendered in the
same risk-verdict teal a "Verified-leaning" badge uses. This class of bug
(a Material default silently pulling from `secondary`, which we
deliberately reserve for verdicts) is worth checking for in any new
selection-style widget added later.

### Applications, Saved Jobs

Two new client-owned collections (`applications`, `savedJobs` —
`ApplicationRepository`/`SavedJobRepository`), unlike
`matchResults`/`scamAssessments`: no "forged verdict" risk in a user
tracking their own self-reported status, so ordinary owner-scoped
Firestore rules apply, no Worker involved. `Application.status` is
purely self-reported (interested/applied/interviewing/offer/rejected) —
nothing verifies it against bdapps or email. Composite indexes
(`userId` + `updatedAt`/`savedAt`) added to `firestore.indexes.json` for
the list queries.

### Job Coach: one AI identity, not three

The app already had three Gemini touchpoints (match reasoning, scam
reasoning, resume tailoring) but never branded any of them "Gemini" in
the UI — there was nothing to remove there. What was missing was a
*coherent* identity tying them together. "Job Coach" (`features/job_coach/`)
is that: a single Worker endpoint (`/v1/job-coach`) handling five fixed
intents plus free-text questions, with a system instruction that
explicitly refuses anything outside job-search/career topics. Reachable
as its own bottom-nav tab, and contextually from a listing ("Get Job
Coach advice" navigates there with `?listingId=` so the same screen picks
up that listing's context) — one underlying system, not a separate
assistant per entry point, per the explicit design requirement.

**Deliberately not built**: persisted multi-turn conversation memory or
streaming responses. Each question is a single request/response (like
resume-tailoring), framed as chat-like UI. True multi-turn memory would
need conversation-state storage and a materially different Worker
architecture — scoped out for now rather than half-built.

### Resume: multi-template guide, not yet multi-version

Built: 5 original ATS-friendly template *guides* (`data/resume_templates.dart`)
— structurally distinct (Classic ATS, Modern Professional, Technical,
Entry-Level, Executive/Minimal), not five cosmetic variants of one layout,
and not copied from any specific named template (those are other
designers' copyrighted layouts) — generic, well-documented ATS
conventions instead (single-column, standard headers, no
tables/graphics).

**Deliberately deferred**: true multiple saved resume versions per user
(e.g. "AI/LLM Resume" vs. "Product Resume", each independently
upload/duplicate/download-able) and an in-app resume editor/builder. The
current model is still one resume per user
(`resumes/{uid}/resume.pdf`) — upgrading to a `users/{uid}/resumes/{id}`
subcollection (already reserved in `firestore.rules` and
`FirestoreCollections.resumes`) is a real, bounded follow-up, not
attempted in this pass alongside everything else.

### Account deletion and profile visibility

`AccountController` deletes everything the client owns before deleting
the Auth account itself (applications, saved jobs, resume file, profile
doc) — **known gap, not swept under the rug**: `matchResults`/
`scamAssessments` are server-write-only, so the client can't purge those;
they hold no identifying data beyond a now-deleted `uid` string, but a
fully complete purge needs a Worker admin endpoint, not built here.

Profile visibility (Public/Private) is a stored preference with nothing
behind it yet — no employer-facing view of any profile exists in the app,
so there's nothing to actually enforce. Built anyway, per an explicit
ask, with the Settings screen's own copy saying so plainly rather than
implying it already controls something.

### Decision: AppsPro for bdapps DCB

The brief calls for bdapps direct carrier billing directly; in practice
this integrates through **AppsPro** (appspro.dev), a subscription-
management layer built on top of bdapps' own telecom API — registering
an app on developer.bdapps.com alone only gets an `applicationId`;
AppsPro is what turns that into OTP-verified phone subscriptions,
webhooks, and a hosted checkout page, without this app needing to
implement SMS/OTP/DCB protocol details itself.

**The credentials, and where each one lives:**
- `publishable_key` (client-safe) → `lib/core/constants/appspro_config.dart`
- `secret_key` (server-only) → `wrangler secret put APPSPRO_SECRET_KEY`,
  never in a file, same treatment as `GEMINI_API_KEY`
- `url_slug` → also `appspro_config.dart`, **still a placeholder** —
  grab the real one from the AppsPro dashboard's API tab

**The one real integration gap, and how it's closed:** AppsPro's hosted
checkout has no documented way to carry our own `uid` through to the
webhook — it only ever reports back a phone number
(`subscriberId: "tel:8801..."`). So phone number is the join key: the
paywall collects it (normalized via `normalizeBdPhoneNumber`) before
opening checkout, and `worker/src/appspro.ts`'s webhook handler queries
`users` by that exact field to find who to credit. A user who somehow
subscribes with a phone number that doesn't match any profile is logged,
not silently dropped — see that file's `findUidByPhone` doc comment.

**Two directions, two different auth stories:**
- bdapps → AppsPro: four fixed URLs (`/bdapps/sms`, `/ussd`, `/notify`,
  `/report`) pasted into the bdapps portal, not something this repo's
  code touches at all — AppsPro's own server handles those.
- AppsPro → us: one webhook (`/v1/appspro-webhook` on the existing
  Worker) configured in AppsPro's dashboard, authenticated by an
  HMAC-SHA256 signature over the canonical (Python `json.dumps(...,
  sort_keys=True)`-equivalent) request body — not a Firebase ID token,
  since this call comes from AppsPro's server, not our client. Checked
  *before* `requireUid` in `index.ts` for exactly that reason.
  `worker/test/appspro.test.ts`'s expected values were computed by
  actually running the sample payload through Python, not guessed —
  getting the canonicalization even slightly wrong (Python's default
  `", "`/`": "` separators, `ensure_ascii` unicode escaping) makes every
  signature check fail, not just edge cases.

**Checkout UX:** hosted checkout (`appspro.dev/s/{url_slug}`) opened in
a WebView (`AppsProCheckoutScreen`), not the embedded WebSDK widget —
matches how the paywall already works (a full screen, not an in-page
widget). Two independent signals detect a completed subscription,
since only one of them is unambiguously documented for hosted checkout
specifically: a `redirect_url` query param intercepted via the
WebView's own navigation delegate (documented for hosted checkout), and
the `"AppsPro"` JavaScript channel AppsPro's SDK posts events through
(documented for the embedded widget — likely but not confirmed to also
fire on the hosted checkout page itself, so treated as a bonus signal,
not the only one relied on).

**Not yet built:** the "Unsubscribe" action (bdapps' own
`/api/v1/sdk/unsubscribe` takes a phone number, not the
`bdappsSubscriptionId` the `Subscription` model already has a field
for — that field name predates having the real API spec; it's still
populated, just not with something usable for unsubscribing directly)
and end-to-end live testing (blocked on the real `url_slug` and a live
AppsPro/bdapps environment to subscribe a real test number against).

## Status

- [x] Project scaffolded (`flutter create`, Android target)
- [x] Folder architecture in place
- [x] Core dependencies chosen and installed
- [x] Firebase project created and wired (`flutterfire configure`)
  - Firestore: created + baseline rules deployed
  - Storage: deliberately not enabled — see "Storage" decision below
  - Auth providers (Email/Password, Google): enabled
  - Debug SHA-1 fingerprint for Google Sign-In: registered — see docs/SETUP.md
- [x] Visual direction confirmed and implemented (theme + motion tokens)
- [x] Data models + Firestore schema — see [docs/DATA_MODELS.md](DATA_MODELS.md)
- [x] Cloudflare Worker (Gemini relay + scam scorer) — see [worker/README.md](../worker/README.md)
  - Rule engine ported to both runtimes: `lib/data/services/scam_rule_engine.dart`
    (instant client-side card badge) and `worker/src/scamRules.ts` (authoritative
    server-side recompute for the shared cached assessment)
  - **Deployed** at `https://trusthire-ai-relay.nafisa-notesapp.workers.dev`
    and verified end-to-end against real Firebase Auth tokens, real
    Firestore reads/writes, and real Gemini calls (both a clean listing
    and one seeded with all five scam signals; a match call producing the
    brief's exact "Matched: X, Y. Gap: Z" format plus a roadmap; cache
    hits confirmed free of a second Gemini spend)
  - Two real bugs caught by that live smoke test, fixed before this was
    marked done: (1) `gemini-2.5-flash` — used at the time this was first
    written — no longer accepts `generateContent` on new projects; Google's
    own error named `gemini-3.6-flash` as the replacement, now confirmed
    available and non-preview via `ListModels`, so the config was updated;
    (2) `auth.ts` let a malformed (but 3-segment-shaped) token throw an
    uncaught `SyntaxError` past the intended `AuthError` handling, landing
    on a generic 500 instead of a clean 401 — now wrapped so any decode
    failure normalizes to `AuthError`, with regression tests added
- [x] Screens — auth (sign in/up, email + Google), onboarding, listings
  feed, listing detail (real match score + trust badge, free/paid gating,
  in-app WebView), profile, paywall, subscription. All wired to Firestore
  and the Worker through repositories; router redirect guards drive the
  auth → onboarding → feed flow.
  **Verified on a real device** (not just an emulator, which repeatedly
  hit unrelated System UI ANRs on this dev machine's older macOS host and
  was abandoned in favor of a physical phone over USB): built and
  installed the debug APK, signed up, completed onboarding (skills,
  headline) — all confirmed working end-to-end by the person actually
  holding the phone, not just by me reading logs.
- [x] Real listing data seeded — see "Decision: JSearch for real
  listings" above and [scripts/seed-listings/README.md](../scripts/seed-listings/README.md).
  54 documents in `listings/`: 50 real Bangladesh postings across 5
  categories (software, marketing, accounting, customer support, design)
  + 4 curated scam-pattern examples spread across the caution/high-risk
  range. Verified via `verify.mjs`, not just trusted after `seed.mjs`
  exited 0: correct counts, no missing titles/descriptions, spot-checked
  a real listing (Sheba.xyz, a genuine Dhaka tech platform) and a scam
  example for field correctness.
- [ ] Web landing page
- [~] bdapps API integration via AppsPro — see "Decision: AppsPro for
  bdapps DCB" above. Built: webhook route (`/v1/appspro-webhook`, HMAC
  signature-verified, unit-tested against real Python-computed values),
  phone-number join key + collection UI, hosted-checkout WebView wired
  to the paywall. Blocked on: the real `url_slug` (placeholder in
  `appspro_config.dart`), configuring that webhook URL + events in
  AppsPro's dashboard, and live end-to-end testing with a real bdapps
  environment. Not built: the unsubscribe action.

### Verified on a real device, against real seeded data

Sign-in, onboarding, the feed, and listing detail all confirmed working
live — not just compiled — on a physical phone over USB, against the 54
listings seeded via `scripts/seed-listings/`:

- Feed renders real listings (Nucs AI, Goinnovior Limited, Sparkrock,
  ...) with skill chips, location, and the instant client-side trust
  badge, with the staggered entrance animation.
- Opening a listing triggers a real `MatchRepository`/`ScamRepository`
  call through to the Worker: match score dial revealed a real
  Gemini-computed percentage (5% against the test profile's skills vs.
  a senior role's Kubernetes/TypeScript/React/SQL requirements — low,
  but that's the model being accurately discriminating, not a bug), and
  the trust badge landed on "Verified-leaning" with all five rule-flag
  checklist items correctly showing clear for a real, clean listing.
- Free-tier gating banner ("Unlock the full gap breakdown...") rendered
  correctly in place of the paid-only reasoning/roadmap section.

Still untested interactively: a scam-example listing's high-risk/caution
path (only a clean listing was opened so far), the in-app WebView opening
a real `job_apply_link`, and the paywall/subscription/profile screens.
