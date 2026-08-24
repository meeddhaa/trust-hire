import 'package:flutter/material.dart';

/// Shown only for the brief window while `authStateProvider`/
/// `currentProfileProvider` resolve on cold start — the router's
/// `redirect` bounces away from here the instant both are known (see
/// `app_router.dart`), so this is never a screen a user lingers on.
class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: Center(child: CircularProgressIndicator()));
  }
}
