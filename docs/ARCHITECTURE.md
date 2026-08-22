# Architecture

## Folder structure

```
lib/
  main.dart                     Entry point: Firebase init, ProviderScope, App
  app.dart                      MaterialApp.router, theme wiring, go_router

  core/
    theme/                      Color system, type scale, motion tokens ("Editorial Trust")
    router/                     go_router route table + guards (auth, onboarding, paywall)
    constants/                  Env keys, Firestore collection names, remote config defaults
    network/                    HTTP client wrapper for the Cloudflare Worker + bdapps API
    errors/                     Typed failures (NetworkFailure, AuthFailure, ...) + mapping
    utils/                      Small pure helpers (formatters, validators)

  data/
    models/                     User, JobListing, MatchResult, ScamAssessment, Subscription
    repositories/                One repository per domain area, hides Firestore/HTTP details
                                 from features (ListingsRepository, MatchRepository,
                                 ScamRepository, SubscriptionRepository, ProfileRepository)
    services/                    Thin wrappers around external SDKs/APIs:
                                 - firebase_auth_service.dart
                                 - firestore_service.dart
                                 - worker_api_service.dart   (Gemini relay calls)
                                 - scam_rule_engine.dart     (client-side deterministic scorer)
                                 - bdapps_api_service.dart   (subscription + unsubscribe)
    seed/                       Curated real BD job listings + realistic scam examples,
                                 loaded into Firestore via a one-time seed script

  features/                     One folder per screen/flow. Each has:
                                   presentation/  screens + feature-local widgets
                                   providers/     Riverpod providers/notifiers for that flow
    onboarding/                 Profile build (skills, experience — typed, no resume upload;
                                 see "Storage" decision below)
    listings/                   Feed: swipeable/scrollable list of JobListingCards
    listing_detail/             Match breakdown, trust badge, in-app WebView to source posting
    paywall/                    bdapps DCB subscription screen
    subscription/               Manage/unsubscribe flow
    profile/                    View/edit profile after onboarding

  shared/
    widgets/                    Cross-feature UI: MatchScoreDial, TrustBadge, EmptyState, etc.
    animations/                 Shared motion primitives (reveal curves, staggered list entries)

test/                           Mirrors lib/ for unit + widget tests
worker/                         Cloudflare Worker (Gemini relay, rate limiting, scam scorer)
web_landing/                    Responsive static landing page (subscription info, bdapps req.)
docs/                           This file, schema notes, decision log
```

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
"not onboarded → onboarding" and "free user hitting a paid action → paywall".

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
`app_motion.dart`, `risk_colors.dart`, `app_theme.dart`). Runnable preview
at `lib/shared/widgets/theme_preview_page.dart` (temporary — see its doc
comment; gets replaced by the real listings feed in step 4).

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
  - Auth providers: manual console step left — see docs/SETUP.md
- [x] Visual direction confirmed and implemented (theme + motion tokens)
- [x] Data models + Firestore schema — see [docs/DATA_MODELS.md](DATA_MODELS.md)
- [ ] Cloudflare Worker (Gemini relay + scam scorer)
- [ ] Screens
- [ ] Web landing page
- [ ] bdapps API integration
