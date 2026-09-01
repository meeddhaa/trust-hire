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
  /// hosted checkout URL (`appspro.dev/s/{urlSlug}`) — from the app's
  /// API tab, "Share URL" field.
  static const String urlSlug = 'JddXhZmKXy';

  /// Not a real, reachable page — a sentinel URL passed as `callback` so
  /// the checkout screen (see `AppsProCheckoutScreen`) can recognize "the
  /// hosted checkout just finished successfully" purely from the
  /// WebView's own navigation events, intercepted before that navigation
  /// ever actually loads.
  ///
  /// `callback` (not `redirect_url`) per this app's own AppsPro dashboard
  /// example — trusted over the generic docs page, which named it
  /// `redirect_url` and described it as a static per-app setting rather
  /// than a per-request query param. That static setting still exists
  /// (AppsPro dashboard → this app → Overview → "Post-checkout redirect
  /// URL") and should ALSO be set to [checkoutSuccessSentinel], as a
  /// fallback in case the dynamic `callback` override here turns out not
  /// to be honored in practice — not yet confirmed live, since checkout
  /// can't be tested end-to-end until this app's phone verification is
  /// fully live.
  ///
  /// Used alongside, not instead of, the "AppsPro" JS channel the docs
  /// describe for the separately-embedded WebSDK widget, since it isn't
  /// explicitly confirmed that the hosted checkout page itself (as
  /// opposed to the embeddable widget) posts through that channel too.
  static const String checkoutSuccessSentinel = 'https://trusthire.app/checkout-success';

  static String get hostedCheckoutUrl =>
      'https://appspro.dev/s/$urlSlug?callback=${Uri.encodeComponent(checkoutSuccessSentinel)}';
}
