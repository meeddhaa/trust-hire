import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../../../core/constants/appspro_config.dart';
import '../../../core/providers/repository_providers.dart';
import '../../../core/providers/session_providers.dart';

/// Embeds AppsPro's WebSDK "subscribe" widget (`appspro.js`) via a hand-
/// built HTML page loaded with `loadHtmlString` — deliberately NOT the
/// hosted checkout page (`appspro.dev/s/{url_slug}`) this screen used to
/// load with `loadRequest`. AppsPro's own docs only document the
/// `window.AppsPro.postMessage` JS channel for the WebSDK widget ("The SDK
/// auto-posts every event to a JavaScript channel named 'AppsPro'" — see
/// the "Flutter / mobile WebView" section); nothing in the docs says the
/// separate hosted checkout page does the same, and its own documented
/// completion signal is a *static*, per-app-configured `checkout_redirect_url`
/// with no dynamic query params — no way to recover a phone number from it.
/// So the widget, embedded in HTML we control, is the only documented path
/// that hands the subscriber's phone number back to native code at all.
///
/// This is also why there's no phone-number field anywhere in this flow
/// upstream of here (see `PaywallScreen`) — the widget's own OTP form is
/// the only place a number is ever typed, and the `success` event's
/// `data.subscriberId` (`"tel:8801..."`) is where this app first learns
/// what it is. That's saved to the profile the moment it arrives, since
/// it's the only join key `worker/src/appspro.ts`'s webhook handler has to
/// match this subscription back to a Firestore user — see
/// `UserProfile.phoneNumber`'s doc comment.
class AppsProCheckoutScreen extends ConsumerStatefulWidget {
  const AppsProCheckoutScreen({super.key});

  @override
  ConsumerState<AppsProCheckoutScreen> createState() => _AppsProCheckoutScreenState();
}

class _AppsProCheckoutScreenState extends ConsumerState<AppsProCheckoutScreen> {
  late final WebViewController _controller;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0xff0f0f13))
      ..addJavaScriptChannel('AppsPro', onMessageReceived: _handleAppsProMessage)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (_) => setState(() => _isLoading = true),
          onPageFinished: (_) => setState(() => _isLoading = false),
        ),
      )
      ..loadHtmlString(_buildHtml());
  }

  // Matches AppsPro's own documented Flutter sample almost verbatim (see
  // this file's class doc comment) — a minimal page whose only job is to
  // mount the subscribe widget and let it auto-post events to the
  // "AppsPro" channel registered above.
  String _buildHtml() => """
<!DOCTYPE html><html><head>
<meta name="viewport" content="width=device-width,initial-scale=1">
<script src="https://appspro.dev/sdk/v1/appspro.js"></script>
</head><body style="margin:0;background:#0f0f13">
<div id="sub"></div>
<script>
  const sdk = AppsPro('${AppsProConfig.publishableKey}', { baseUrl: '${AppsProConfig.sdkBaseUrl}' });
  const el = sdk.elements.create('subscribe', {
    buttonText: 'Subscribe with OTP',
    theme: 'dark',
  });
  el.mount('#sub');
</script></body></html>""";

  void _handleAppsProMessage(JavaScriptMessage message) {
    final parsed = jsonDecode(message.message) as Map<String, dynamic>;
    final type = parsed['type'] as String?;

    switch (type) {
      case 'success':
        _handleSuccess(parsed['data'] as Map<String, dynamic>?);
      case 'error':
        final data = parsed['data'] as Map<String, dynamic>?;
        final errorMessage = data?['message'] as String? ?? 'Something went wrong during checkout.';
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text(errorMessage)));
      // 'ready' / 'otp-sent' / 'payment-redirect' need no handling here —
      // the widget's own UI already reflects those states.
    }
  }

  /// `data.subscriberId` arrives as `"tel:8801712345678"` — the same shape
  /// `worker/src/appspro.ts`'s `phoneFromSubscriberId` strips server-side.
  String? _phoneFromSubscriberId(dynamic subscriberId) {
    if (subscriberId is! String) return null;
    final withoutPrefix = subscriberId.startsWith('tel:') ? subscriberId.substring(4) : subscriberId;
    return withoutPrefix.isEmpty ? null : withoutPrefix;
  }

  Future<void> _handleSuccess(Map<String, dynamic>? data) async {
    final phone = _phoneFromSubscriberId(data?['subscriberId']);
    if (phone != null) {
      final uid = ref.read(currentUidProvider);
      if (uid != null) {
        try {
          // setPhoneNumber normalizes internally — see its doc comment.
          await ref.read(profileRepositoryProvider).setPhoneNumber(uid, phone);
        } catch (_) {
          // Non-fatal: AppsPro already has the subscription regardless of
          // whether this write lands. Surfacing an error here after a
          // successful subscribe would read as "did it work or not?" to
          // the user, which is worse than silently retrying to save the
          // join key some other way later (e.g. a manual profile edit).
        }
      }
    }
    // No `else` — nothing in AppsPro's docs says `success` can fire without
    // a `subscriberId`, but if it somehow does, there's nothing more to do
    // about it client-side; the webhook simply won't find a match.
    if (!mounted) return;
    // Pop with `true` — the caller (paywall_screen.dart) shows its own
    // confirmation copy rather than this screen doing it, since by the
    // time this pops the paywall is what's visible again.
    if (Navigator.of(context).canPop()) Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Subscribe')),
      body: Stack(
        children: [
          WebViewWidget(controller: _controller),
          if (_isLoading) const LinearProgressIndicator(minHeight: 2),
        ],
      ),
    );
  }
}
