import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

/// In-app WebView for the original job posting — the "live web browsing"
/// capability the bdapps brief requires (not just a static description
/// screen). Its own route (not embedded in listing detail) so it gets its
/// own back-stack entry: back from here returns to the listing, not out
/// of the app.
class SourceWebviewScreen extends StatefulWidget {
  const SourceWebviewScreen({super.key, required this.url, required this.title});

  final String url;
  final String title;

  @override
  State<SourceWebviewScreen> createState() => _SourceWebviewScreenState();
}

class _SourceWebviewScreenState extends State<SourceWebviewScreen> {
  late final WebViewController _controller;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (_) => setState(() => _isLoading = true),
          onPageFinished: (_) => setState(() => _isLoading = false),
        ),
      )
      ..loadRequest(Uri.parse(widget.url));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.title, overflow: TextOverflow.ellipsis)),
      body: Stack(
        children: [
          WebViewWidget(controller: _controller),
          if (_isLoading) const LinearProgressIndicator(minHeight: 2),
        ],
      ),
    );
  }
}
