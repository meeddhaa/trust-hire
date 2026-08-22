# TrustHire

An AI-powered job listings app for the bdapps National Android Development
Bootcamp final submission.

Two features sit on top of a curated job feed:

1. **Explainable Job Match** — not just a match percentage. Shows matched
   skills, gap skills, and a short plain-language reasoning string.
2. **Scam Risk Detection** — a deterministic rule-based fraud score (upfront
   fees, unrealistic salary, no verifiable company domain, urgency language,
   WhatsApp-only contact) feeds an LLM call that turns the flags into a
   plain-language trust badge and explanation.

Free tier: match % + trust badge. Paid tier (bdapps DCB subscription): full
gap breakdown, personalized upskilling roadmap, full scam-risk reasoning.

See [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) for the project structure,
data flow, and the reasoning behind each technical choice.

## Repo layout

```
trusthire/          Flutter app (this directory)
worker/              Cloudflare Worker — Gemini relay + scam rule engine
web_landing/         Responsive web landing page (subscription info)
docs/                Architecture notes, schema, decisions
```

## Getting started

```bash
flutter pub get
flutter run
```

Firebase config and the Worker URL are read from `--dart-define` values /
`lib/core/constants/env.dart` — see [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md)
for setup steps before first run.
