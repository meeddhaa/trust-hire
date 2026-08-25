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

## Decision: Firebase Storage and resume upload, reconsidered

Firebase requires the **Blaze** (pay-as-you-go) plan to use Storage at
all, even at zero usage — Spark doesn't support it. Originally decided
against enabling it for exactly that reason: onboarding collected skills
as typed input instead of a parsed resume, and `UserProfile.resumeStoragePath`
was left in the model, nullable and unused, in case this got revisited.

It got revisited: after using the app, real resume-based matching (not
just typed skill chips) was specifically asked for, along with an actual
Gemini-powered resume-tailoring feature per listing — a materially
different, higher-value AI feature than typed-skill matching alone, and
worth the Blaze upgrade for. `storage.rules` (owner-only, PDF-only, 10MB
cap) was already written and just needed deploying once Storage was
enabled.

**How the PDF reaches Gemini**: no separate text-extraction step. The
Worker's `/v1/resume-tailor` endpoint fetches the raw PDF bytes straight
from Cloud Storage (`storageClient.ts`, read-only GCS REST access on the
same service-account token as Firestore — scope extended in
`serviceAccountAuth.ts`, which both clients now share) and sends them to
Gemini as inline document data (`gemini.ts`'s `InlineFile` parts) —
Gemini reads PDF content natively. Simpler and more robust than adding a
PDF-parsing library, and one less thing that can silently mis-extract
text from a resume's layout.

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
- [ ] bdapps API integration (paywall/subscription UI exists; the actual
  checkout + webhook + unsubscribe call are step 7)

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
