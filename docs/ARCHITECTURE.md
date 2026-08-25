# Architecture

## Folder structure

```
lib/
  main.dart                     Entry point: Firebase init, ProviderScope, App
  app.dart                      MaterialApp.router (ConsumerWidget, watches goRouterProvider)

  core/
    theme/                      Color system, type scale, motion tokens ("Editorial Trust")
    router/                     app_router.dart (goRouterProvider: route table + redirect
                                 guards for auth/onboarding), splash_screen.dart
    providers/                  Cross-feature Riverpod DI: repository_providers.dart
                                 (one Provider per repository/service), session_providers.dart
                                 (currentUidProvider, currentProfileProvider,
                                 currentSubscriptionProvider) — added beyond the original
                                 per-feature-only plan once 3+ features needed the same
                                 profile/subscription state; see "Why core/providers/" below
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
    seed/                       Curated real BD job listings + realistic scam examples —
                                 step 5, not built yet (empty listings collection today)

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
    profile/                    View profile + sign out + jump to subscription. Editing
                                 beyond what onboarding collects is a natural follow-up once
                                 this and paywall/subscription are both settled

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

## Visual direction: Editorial Trust (confirmed)

Warm paper/ink base, single burnt-amber accent, a *separate* muted
verdict scale (slate-teal / amber / brick) reserved for trust badges and
match scores so they read as data, not brand decoration. Fraunces (serif)
for score numerals and verdict headlines; Manrope (grotesk) for everything
else. Motion is confident, not bouncy: radial arc + count-up for the match
score, a brief hold-then-stamp for the trust badge, accordion expand (not
modal) for the gap breakdown, staggered entrance for feed cards.

Implemented in `lib/core/theme/` (`app_colors.dart`, `app_typography.dart`,
`app_motion.dart`, `risk_colors.dart`, `app_theme.dart`). The temporary
preview page is gone — `MatchScoreDial` and `TrustBadgeChip` (its
score-dial and badge-reveal widgets) were promoted into
`shared/widgets/` and are now driven by real data in `listing_detail`.

## Decision: no Firebase Storage, no resume upload (for now)

Firebase now requires the **Blaze** (pay-as-you-go) plan to use Storage at
all, even at zero usage — Spark no longer supports it. That means adding a
billing card to a bootcamp project just to hold a handful of PDFs, for a
feature the brief only asks for conditionally ("Storage if needed for
resume/CV upload").

Decided against it: onboarding collects skills, experience, and education
as typed structured input instead of a parsed resume. This is what
actually feeds the match-gap Gemini call anyway (`UserProfile.skills` diffed
against `JobListing.requiredSkills`) — a resume would need parsing into
the same structured shape regardless, so skipping the upload step removes
a dependency (Storage, a PDF parser) without changing what the AI feature
does. `UserProfile.resumeStoragePath` stays in the model as a nullable,
currently-unused field — cheap to leave in, and re-enabling upload later
(if the team decides it's worth the Blaze upgrade) needs no schema change,
just wiring a picker + Storage service back in.

`storage.rules` stays in the repo, unused, for the same reason.

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
  auth → onboarding → feed flow. Not yet exercised on a real device or
  against seeded data — `flutter analyze` and `flutter test` are clean,
  but the feed will show its empty state until step 5 seeds `listings`,
  and sign-in itself hasn't been run interactively (see "Not yet verified"
  below)
- [ ] Web landing page
- [ ] bdapps API integration (paywall/subscription UI exists; the actual
  checkout + webhook + unsubscribe call are step 7)

### Not yet verified

Everything above compiles and typechecks, and the AI pipeline itself was
proven live in step 3's smoke test (real Gemini calls, real Firestore
writes) — but the screens built in this step haven't been run
interactively on a device/emulator yet, only statically analyzed. Before
calling step 4 done: sign in (email + Google) end-to-end, complete
onboarding, confirm the router guards actually redirect correctly, and —
once step 5 seeds real listings — open a listing and confirm the match
score and trust badge render against a real Worker response, not just a
mocked one.
