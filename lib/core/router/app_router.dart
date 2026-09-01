import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../features/applications/presentation/applications_screen.dart';
import '../../features/auth/presentation/sign_in_screen.dart';
import '../../features/auth/providers/auth_providers.dart';
import '../../features/dashboard/presentation/dashboard_screen.dart';
import '../../features/job_coach/presentation/job_coach_screen.dart';
import '../../features/listing_detail/presentation/listing_detail_screen.dart';
import '../../features/listings/presentation/listings_feed_screen.dart';
import '../../features/onboarding/presentation/onboarding_screen.dart';
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
/// Primary navigation is a `StatefulShellRoute` (Dashboard / Jobs /
/// Applications / Job Coach / Profile), each branch keeping its own
/// stack — so pushing a listing detail from Jobs doesn't disturb
/// Applications' scroll position, and switching tabs doesn't lose either.
/// Dashboard is the actual landing screen (real stats + quick actions);
/// Jobs stays a pure listings browser rather than doing double duty as
/// home, per explicit feedback. Saved isn't a bottom-nav tab — six tabs
/// overflowed the floating nav bar on real device widths, and Saved was
/// the one asked to move — it lives in the drawer instead, alongside
/// Resume/Settings/Subscription. Account management (that same group)
/// lives outside the shell entirely, reached via the drawer — see
/// `app_drawer.dart` and docs/ARCHITECTURE.md → "Decision: navigation
/// drawer" for why the two are kept apart.
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
              GoRoute(path: '/dashboard', builder: (context, state) => const DashboardScreen()),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(path: '/listings', builder: (context, state) => const ListingsFeedScreen()),
            ],
          ),
          StatefulShellBranch(routes: [
            GoRoute(path: '/applications', builder: (context, state) => const ApplicationsScreen()),
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

      // Listing detail — outside the shell, not nested under `/listings`
      // as a shell-branch child route as it originally was: nesting it
      // there kept the shell's persistent bottom nav bar visible behind
      // the detail screen's own pinned "View original posting" button,
      // stacking two bottom bars on top of each other (a real bug, caught
      // live on device once that button became a pinned
      // `bottomNavigationBar` rather than just the last item in the
      // scroll content). A top-level route pushes fully over the shell,
      // same as Settings/Resume/etc. below.
      GoRoute(
        path: '/listings/:id',
        builder: (context, state) => ListingDetailScreen(listingId: state.pathParameters['id']!),
      ),

      // Saved jobs — outside the shell, reached via the drawer (see this
      // file's top doc comment for why it isn't a bottom-nav tab).
      GoRoute(path: '/saved', builder: (context, state) => const SavedJobsScreen()),

      // Account management — outside the shell, pushed on top with a
      // normal back button, reached via the drawer.
      GoRoute(path: '/settings', builder: (context, state) => const SettingsScreen()),
      GoRoute(path: '/resume', builder: (context, state) => const ResumeScreen()),
      GoRoute(path: '/subscription', builder: (context, state) => const SubscriptionScreen()),
    ],
  );
});

String? _redirect(Ref ref, GoRouterState state) {
  final authState = ref.read(authStateProvider);
  if (authState.isLoading) return null; // splash stays until we know

  final isSignedIn = authState.valueOrNull != null;
  final onSignIn = state.matchedLocation == '/sign-in';

  if (!isSignedIn) return onSignIn ? null : '/sign-in';

  // Signing in IS subscribing now (see `SignInScreen`'s doc comment) — but
  // a subscription can still lapse afterward (a cancellation from BDApps'
  // own side, caught by the webhook; or this app's own periodic refresh
  // finding it invalid). There's no free tier to fall back to: an
  // inactive subscription sends the user right back through `/sign-in` to
  // resubscribe, exactly like a first-time sign-in.
  final subscriptionState = ref.read(currentSubscriptionProvider);
  if (subscriptionState.isLoading) return null; // splash stays until we know
  final isSubscribed = subscriptionState.valueOrNull?.isPaid ?? false;
  if (!isSubscribed) return onSignIn ? null : '/sign-in';

  final profileState = ref.read(currentProfileProvider);
  if (profileState.isLoading) return null; // splash stays until profile is known

  final onboardingComplete = profileState.valueOrNull?.onboardingComplete ?? false;
  final onOnboarding = state.matchedLocation == '/onboarding';

  if (!onboardingComplete) return onOnboarding ? null : '/onboarding';
  if (onSignIn || onOnboarding || state.matchedLocation == '/') return '/dashboard';

  return null;
}

/// Bridges Riverpod's `ref.listen` to `GoRouter`'s `Listenable`-based
/// refresh mechanism — `ChangeNotifier.notifyListeners()` is what makes
/// `GoRouter` re-run `redirect` after auth, subscription, or profile state
/// changes.
class _RouterRefreshNotifier extends ChangeNotifier {
  _RouterRefreshNotifier(Ref ref) {
    ref.listen(authStateProvider, (_, _) => notifyListeners());
    ref.listen(currentSubscriptionProvider, (_, _) => notifyListeners());
    ref.listen(currentProfileProvider, (_, _) => notifyListeners());
  }
}
