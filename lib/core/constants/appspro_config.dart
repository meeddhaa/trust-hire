/// AppsPro (bdapps DCB subscription platform) client-side config — see
/// docs/ARCHITECTURE.md → "Decision: AppsPro for bdapps DCB" and
/// `worker/src/appspro.ts` for the server side (webhook verification,
/// signed with a secret_key that never appears here).
///
/// [publishableKey] is explicitly client-safe per AppsPro's own docs (the
/// "pk_" prefix mirrors Stripe's convention for the same reason) — unlike
/// `secret_key`, which is a Worker-only secret (`wrangler secret put
/// APPSPRO_SECRET_KEY`) and must never be added here.
abstract final class AppsProConfig {
  static const String publishableKey = 'pk_7c0c2508506cbddfa66c6731';

  /// The WebSDK (`appspro.js`) requires this explicitly — per AppsPro's own
  /// docs, "The SDK does not auto-detect this: the script is served from
  /// appspro.dev but the API lives on api.appspro.dev".
  static const String sdkBaseUrl = 'https://api.appspro.dev';
}
