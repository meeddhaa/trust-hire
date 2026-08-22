import 'package:go_router/go_router.dart';
import '../../shared/widgets/theme_preview_page.dart';

/// Route table. Only a theme-preview placeholder exists so far — real
/// routes (onboarding, listings, listing_detail, paywall, subscription,
/// profile) land in build-order step 4, along with auth/onboarding
/// redirect guards.
final appRouter = GoRouter(
  initialLocation: '/',
  routes: [
    GoRoute(
      path: '/',
      builder: (context, state) => const ThemePreviewPage(),
    ),
  ],
);
