import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../features/auth/presentation/sign_in_screen.dart';
import '../../features/auth/providers/auth_providers.dart';
import '../../features/listing_detail/presentation/listing_detail_screen.dart';
import '../../features/listings/presentation/listings_feed_screen.dart';
import '../../features/onboarding/presentation/onboarding_screen.dart';
import '../../features/paywall/presentation/paywall_screen.dart';
import '../../features/profile/presentation/profile_screen.dart';
import '../../features/subscription/presentation/subscription_screen.dart';
import 'splash_screen.dart';
import '../providers/session_providers.dart';

/// Route table with auth/onboarding redirect guards, built as a
/// `Provider` (not a top-level `final`) so `redirect` can read live
/// Riverpod state — see `_RouterRefreshNotifier` for how state changes
/// (sign in/out, onboarding completing) trigger a re-evaluation without
/// recreating the `GoRouter` instance itself (which would blow away the
/// navigation stack on every auth change).
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
      GoRoute(path: '/listings', builder: (context, state) => const ListingsFeedScreen()),
      GoRoute(
        path: '/listings/:id',
        builder: (context, state) => ListingDetailScreen(listingId: state.pathParameters['id']!),
      ),
      GoRoute(path: '/profile', builder: (context, state) => const ProfileScreen()),
      GoRoute(path: '/paywall', builder: (context, state) => const PaywallScreen()),
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
