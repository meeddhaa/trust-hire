# Data models & Firestore schema

Step 2 of the build order. Five models in `lib/data/models/`, each with
`fromMap`/`toMap` (Firestore `Map<String, dynamic>` in/out) and value
equality via `Equatable`. Timestamp↔DateTime conversion is centralized in
[`core/utils/firestore_codec.dart`](../lib/core/utils/firestore_codec.dart)
so every model's conversion logic is one line, not five copies.

No code generation (freezed/json_serializable) — five hand-written models
is well under the point where codegen pays for itself, and it keeps the
build free of a `.g.dart` step for a judged demo.

## Collections

Names centralized in
[`core/constants/firestore_collections.dart`](../lib/core/constants/firestore_collections.dart),
kept in sync with the `match` paths in [`firestore.rules`](../firestore.rules).

| Collection | Doc ID | Model | Written by | Read by |
|---|---|---|---|---|
| `users` | `{uid}` | `UserProfile` | Client (owner only) | Client (owner only) |
| `listings` | `{listingId}` | `JobListing` | Seed script (Admin SDK) | Any signed-in client |
| `matchResults` | `{userId}_{listingId}` | `MatchResult` | Cloudflare Worker only | Client, own results only |
| `scamAssessments` | `{listingId}` | `ScamAssessment` | Cloudflare Worker only | Any signed-in client |
| `subscriptions` | `{uid}` | `Subscription` | bdapps webhook handler only | Client (owner only) |

The client-write-nothing rule for `matchResults`/`scamAssessments`/
`subscriptions` (see `firestore.rules`) is what makes it safe to store the
*full* AI output rather than a tier-gated subset — a modified client can
read the paid fields but can never forge them, and the UI layer (not the
data layer) decides what a free-tier user actually gets shown. See
`docs/ARCHITECTURE.md` → "Data flow: match + scam assessment".

## Model summaries

**`UserProfile`** (`user_profile.dart`) — profile built during onboarding:
skills (the input side of the match diff), experience, resume storage
path, onboarding-complete flag the router redirects on. Named `UserProfile`
rather than `User` to avoid colliding with `firebase_auth`'s `User`.

**`JobListing`** (`job_listing.dart`) — a seeded listing. Fields double as
raw input to the rule-based scam scorer (step 3): `companyDomain`,
`salaryMin`/`Max`, `contactMethod`/`contactValue`, `applicationFeeRequired`
map onto four of the five scam signals; the fifth (urgency language) is
parsed from `description` at scoring time rather than stored as a flag.
`sourceUrl` is what the in-app WebView opens — the brief's "live web
browsing" requirement.

**`ScamRuleFlags`** (`scam_rule_flags.dart`) — the five booleans from the
brief (upfront fees, unrealistic salary, no verifiable domain, urgency
language, WhatsApp-only contact) plus a `triggeredCount` getter. Computed
client-side, instantly, with no network call (`data/services/
scam_rule_engine.dart`, step 3) so every feed card gets a preliminary
badge before a listing is ever opened. The same shape is embedded inside a
cached `ScamAssessment` once the LLM call resolves, so "what the instant
badge showed" and "what got persisted" can never disagree.

**`MatchResult`** (`match_result.dart`) — cached per `(user, listing)`.
Deliberately stores the full result (matched/gap skills, reasoning,
upskilling roadmap) regardless of viewer tier; free vs. paid gating is a
UI-layer decision, not a data-shape decision, so upgrading mid-session
needs no re-fetch. `modelVersion` lets a prompt change invalidate old
cache entries without a schema migration — a stale version is just
treated as a cache miss by the repository.

**`ScamAssessment`** (`scam_assessment.dart`) — cached per listing (not
per user — a listing's fraud risk doesn't depend on who's asking). Holds
the deterministic `ruleScore`/`ruleFlags` alongside the LLM's plain-
language `reasoning`, and the three-way `TrustBadge` (`verifiedLeaning` /
`caution` / `highRisk`) both tiers see on the card.

**`Subscription`** (`subscription.dart`) — bdapps DCB state per user.
`isPaid` checks both `tier` and `status` (not tier alone) so a
cancellation that hasn't reached period end doesn't need a second flag.
`Subscription.free(uid)` gives the default shape for a user who has never
subscribed, so "no document" and "explicitly free" read identically
everywhere else in the app.

## Status

- [x] Models + schema (this doc)
- [ ] Firestore composite indexes — none needed yet; added in step 4 once
      actual feed/history queries are written (`firestore.indexes.json` is
      still empty by design, not an oversight)
- [ ] Repositories (`data/repositories/`) that read/write these models —
      step 4, alongside the screens that need them
