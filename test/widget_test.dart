// Basic smoke test: the app boots and renders its root route without
// throwing. Firebase.initializeApp is skipped here (no test bootstrap yet)
// so this exercises the theme/router wiring, not the full app.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trusthire/core/router/app_router.dart';
import 'package:trusthire/core/theme/app_theme.dart';

void main() {
  testWidgets('renders theme preview root route', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp.router(
          theme: AppTheme.light(),
          routerConfig: appRouter,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Editorial Trust'), findsOneWidget);
  });
}
