import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../features/applications/presentation/applications_screen.dart';
import '../../features/auth/presentation/sign_in_screen.dart';
import '../../features/auth/providers/auth_providers.dart';
import '../../features/job_coach/presentation/job_coach_screen.dart';
import '../../features/listing_detail/presentation/listing_detail_screen.dart';
import '../../features/listings/presentation/listings_feed_screen.dart';
import '../../features/onboarding/presentation/onboarding_screen.dart';
import '../../features/paywall/presentation/paywall_screen.dart';
import '../../features/profile/presentation/profile_screen.dart';
import '../../features/saved_jobs/presentation/saved_jobs_screen.dart';
import '../../features/settings/presentation/resume_screen.dart';
import '../../features/settings/presentation/settings_screen.dart';
import '../../features/subscription/presentation/subscription_screen.dart';
import 'main_shell.dart';
import 'splash_screen.dart';
import '../providers/session_providers.dart';

/// Route table with auth/onboarding redirect guards, built as a
/// `Provider` (not a top-level `final`) so `redirect` can read live
/// Riverpod state — see `_RouterRefreshNotifier` for how state changes
/// (sign in/out, onboarding completing) trigger a re-evaluation without
/// recreating the `GoRouter` instance itself (which would blow away the
/// navigation stack on every auth change).
///
/// Primary navigation is a `StatefulShellRoute` (Jobs / Applications /
/// Saved / Job Coach / Profile), each branch keeping its own stack — so
/// pushing a listing detail from Jobs doesn't disturb Applications'
/// scroll position, and switching tabs doesn't lose either. Account
/// management (Resume/Settings/Subscription/Sign out) lives outside the
/// shell entirely, reached via the drawer — see `app_drawer.dart` and
/// docs/ARCHITECTURE.md → "Decision: navigation drawer" for why the two
/// are kept apart.
final goRouterProvider = Provider<GoRouter>((ref) {
  final refreshNotifier = _RouterRefreshNotifier(ref);

  return GoRouter(
    initialLocation: '/',
    refreshListenable: refreshNotifier,
    redirect: (context, state) => _redirect(ref, state),
    routes: [
      GoRoute(path: '/', builder: (context, state) => const SplashScreen()),
      GoRoute(path: '/sign-in', builder: (context, state) => const SignInScreen()),
      GoRoute(path: '/onboarding', builder: (context, state) => const OnboardingScreen()),

      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) => MainShell(navigationShell: navigationShell),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/listings',
                builder: (context, state) => const ListingsFeedScreen(),
                routes: [
                  GoRoute(
                    path: ':id',
                    builder: (context, state) => ListingDetailScreen(listingId: state.pathParameters['id']!),
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(routes: [
            GoRoute(path: '/applications', builder: (context, state) => const ApplicationsScreen()),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(path: '/saved', builder: (context, state) => const SavedJobsScreen()),
          ]),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/job-coach',
                builder: (context, state) =>
                    JobCoachScreen(listingId: state.uri.queryParameters['listingId']),
              ),
            ],
          ),
          StatefulShellBranch(routes: [
            GoRoute(path: '/profile', builder: (context, state) => const ProfileScreen()),
          ]),
        ],
      ),

      // Account management — outside the shell, pushed on top with a
      // normal back button, reached via the drawer.
      GoRoute(path: '/settings', builder: (context, state) => const SettingsScreen()),
      GoRoute(path: '/resume', builder: (context, state) => const ResumeScreen()),
      GoRoute(path: '/subscription', builder: (context, state) => const SubscriptionScreen()),
      GoRoute(path: '/paywall', builder: (context, state) => const PaywallScreen()),
    ],
  );
});

String? _redirect(Ref ref, GoRouterState state) {
  final authState = ref.read(authStateProvider);
  if (authState.isLoading) return null; // splash stays until we know

  final isSignedIn = authState.valueOrNull != null;
  final onSignIn = state.matchedLocation == '/sign-in';

  if (!isSignedIn) return onSignIn ? null : '/sign-in';

  final profileState = ref.read(currentProfileProvider);
  if (profileState.isLoading) return null; // splash stays until profile is known

  final onboardingComplete = profileState.valueOrNull?.onboardingComplete ?? false;
  final onOnboarding = state.matchedLocation == '/onboarding';

  if (!onboardingComplete) return onOnboarding ? null : '/onboarding';
  if (onSignIn || onOnboarding || state.matchedLocation == '/') return '/listings';

  return null;
}

/// Bridges Riverpod's `ref.listen` to `GoRouter`'s `Listenable`-based
/// refresh mechanism — `ChangeNotifier.notifyListeners()` is what makes
/// `GoRouter` re-run `redirect` after auth or profile state changes.
class _RouterRefreshNotifier extends ChangeNotifier {
  _RouterRefreshNotifier(Ref ref) {
    ref.listen(authStateProvider, (_, _) => notifyListeners());
    ref.listen(currentProfileProvider, (_, _) => notifyListeners());
  }
}
