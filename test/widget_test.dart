// Smoke test for the splash screen in isolation. The real app's routed
// screens (sign-in, listings, ...) sit behind Riverpod providers that
// touch `FirebaseAuth.instance` as soon as they're read — even just
// resolving `goRouterProvider` requires `authStateProvider`, which needs
// `Firebase.initializeApp()` to have run first. That needs a Firebase
// test harness (fake/mocked platform channels) this project doesn't have
// set up yet, so this test is deliberately scoped to what's testable
// without one: the splash screen renders correctly on its own. See
// `test/data/scam_rule_engine_test.dart` for real business-logic coverage
// that also needs no Firebase bootstrap.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trusthire/core/router/splash_screen.dart';

void main() {
  testWidgets('SplashScreen shows a loading indicator', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: SplashScreen()));

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });
}
