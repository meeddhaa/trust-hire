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

  /// The 10-char base62 handle AppsPro's dashboard shows for this app's
  /// hosted checkout URL (`appspro.dev/s/{urlSlug}`) — still needed:
  /// grab it from the app's API tab in the AppsPro dashboard (same place
  /// `publishableKey` above came from) and paste it in here.
  static const String urlSlug = 'REPLACE_WITH_URL_SLUG';

  /// Not a real, reachable page — a sentinel URL passed as `redirect_url`
  /// so the checkout screen (see `AppsProCheckoutScreen`) can recognize
  /// "the hosted checkout just finished successfully" purely from the
  /// WebView's own navigation events, intercepted before that navigation
  /// ever actually loads. This is the documented mechanism specifically
  /// for the Hosted Checkout path (`GET/POST /s/{url_slug}/*` responses
  /// include a `redirect_url` field, and the WebSDK's own
  /// `createCheckoutUrl({ redirectUrl })` helper builds this exact query
  /// param) — used alongside, not instead of, the "AppsPro" JS channel
  /// the docs describe for the separately-embedded WebSDK widget, since
  /// it isn't explicitly confirmed that the hosted checkout page itself
  /// (as opposed to the embeddable widget) posts through that channel too.
  static const String checkoutSuccessSentinel = 'https://trusthire.app/checkout-success';

  static String get hostedCheckoutUrl =>
      'https://appspro.dev/s/$urlSlug?redirect_url=${Uri.encodeComponent(checkoutSuccessSentinel)}';
}
