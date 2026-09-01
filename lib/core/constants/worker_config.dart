/// Cloudflare Worker relay config. Must stay in sync with `worker/wrangler.jsonc`
/// — see `worker/README.md` for the deployed URL and `docs/ARCHITECTURE.md`
/// for why the client calls the Worker instead of Firestore directly for
/// match/scam results (the Worker holds the Gemini key and does the LLM call).
abstract final class WorkerConfig {
  static const String baseUrl = 'https://trusthire-ai-relay.nafisa-notesapp.workers.dev';

  static const String matchPath = '/v1/match';
  static const String scamAssessmentPath = '/v1/scam-assessment';
  static const String resumeTailorPath = '/v1/resume-tailor';
  static const String jobCoachPath = '/v1/job-coach';
  static const String resumeSkillsPath = '/v1/resume-skills';

  /// The bdapps phone+OTP sign-in flow (see `worker/src/subscription.ts`
  /// and `worker/src/index.ts`'s `/v1/auth/*` routes) — every privileged
  /// AppsPro call (Bearer `secret_key`) happens behind these, never
  /// directly from this app. Unlike every other path here, these two
  /// carry no Firebase ID token — there's no session yet at this point,
  /// that's the whole reason they exist (see `ApiClient.postJson`).
  static const String authOtpRequestPath = '/v1/auth/otp/request';
  static const String authOtpVerifyPath = '/v1/auth/otp/verify';

  /// Re-checks the current (already signed-in) subscription's live status
  /// — see `SubscriptionScreen`.
  static const String subscriptionRefreshPath = '/v1/subscription/refresh';

  /// Mirrors the Worker's `MATCH_MODEL_VERSION`/`SCAM_MODEL_VERSION` vars.
  /// Used client-side only to decide whether a Firestore-cached result is
  /// still fresh before bothering to call the Worker at all — the Worker
  /// re-checks this itself regardless, so a stale constant here just costs
  /// an extra round trip, never correctness.
  static const String matchModelVersion = 'gemini-3.6-flash@match-v1';
  static const String scamModelVersion = 'gemini-3.6-flash@scam-v1';
}
