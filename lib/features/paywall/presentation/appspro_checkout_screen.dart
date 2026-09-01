import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../../../core/constants/appspro_config.dart';

/// Loads AppsPro's hosted checkout page (`appspro.dev/s/{urlSlug}`) in a
/// WebView and listens for its real-time events — the WebSDK auto-posts
/// every step (`ready`/`otp-sent`/`success`/`payment-redirect`/`error`) to
/// a JS channel literally named "AppsPro" (per AppsPro's own docs: "No
/// extra JS wiring is needed inside the WebView" beyond registering that
/// channel), so this needs no custom JavaScript injected — just the
/// channel registration below.
///
/// This screen only reports what AppsPro's own checkout UI told the
/// browser happened; it does NOT itself flip `subscriptions/{uid}` to
/// paid — that only happens once AppsPro's server calls our Worker's
/// `/v1/appspro-webhook` (see `worker/src/appspro.ts`), which can arrive
/// slightly after 'success' fires here. `currentSubscriptionProvider`
/// (a live Firestore stream) picks up that change on its own once it
/// lands; this screen just gives the user an honest "you're subscribed"
/// moment and returns them to the paywall.
class AppsProCheckoutScreen extends StatefulWidget {
  const AppsProCheckoutScreen({super.key});

  @override
  State<AppsProCheckoutScreen> createState() => _AppsProCheckoutScreenState();
}

class _AppsProCheckoutScreenState extends State<AppsProCheckoutScreen> {
  late final WebViewController _controller;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..addJavaScriptChannel('AppsPro', onMessageReceived: _handleAppsProMessage)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (_) => setState(() => _isLoading = true),
          onPageFinished: (_) => setState(() => _isLoading = false),
          // The documented signal specifically for Hosted Checkout (as
          // opposed to the embedded WebSDK widget's JS channel, handled
          // below) — see AppsProConfig.checkoutSuccessSentinel's doc
          // comment. Intercepted before it ever actually loads: this
          // sentinel URL isn't a real page.
          onNavigationRequest: (request) {
            if (request.url.startsWith(AppsProConfig.checkoutSuccessSentinel)) {
              if (Navigator.of(context).canPop()) Navigator.of(context).pop(true);
              return NavigationDecision.prevent;
            }
            return NavigationDecision.navigate;
          },
        ),
      )
      ..loadRequest(Uri.parse(AppsProConfig.hostedCheckoutUrl));
  }

  void _handleAppsProMessage(JavaScriptMessage message) {
    final parsed = jsonDecode(message.message) as Map<String, dynamic>;
    final type = parsed['type'] as String?;

    switch (type) {
      case 'success':
        // Pop with `true` — the caller (paywall_screen.dart) shows its own
        // confirmation copy rather than this screen doing it, since by
        // the time this pops the paywall is what's visible again.
        if (Navigator.of(context).canPop()) Navigator.of(context).pop(true);
      case 'error':
        final data = parsed['data'] as Map<String, dynamic>?;
        final errorMessage = data?['message'] as String? ?? 'Something went wrong during checkout.';
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text(errorMessage)));
      // 'ready' / 'otp-sent' / 'payment-redirect' need no handling here —
      // the hosted checkout page's own UI already reflects those states.
    }
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
