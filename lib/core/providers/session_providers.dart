import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/subscription.dart';
import '../../data/models/user_profile.dart';
import '../../features/auth/providers/auth_providers.dart';
import 'repository_providers.dart';

/// Derives the signed-in user's `uid` from auth state — `null` while
/// signed out or while auth state is still loading on cold start.
final currentUidProvider = Provider<String?>((ref) {
  return ref.watch(authStateProvider).value?.uid;
});

/// Live profile for whoever's currently signed in. Shared across the
/// router's onboarding guard, the onboarding screen, and the profile
/// feature (step 4's later screens) — hence living in `core/`, not any
/// one feature's `providers/` folder.
final currentProfileProvider = StreamProvider<UserProfile?>((ref) {
  final uid = ref.watch(currentUidProvider);
  if (uid == null) return Stream.value(null);
  return ref.watch(profileRepositoryProvider).watchProfile(uid);
});

/// Live subscription state for whoever's signed in. Also what the
/// router's redirect guard gates on — there's no free tier, so a signed-in
/// but unsubscribed/lapsed user is sent straight back to `/sign-in` (see
/// `app_router.dart`). Shared across `listing_detail` (defensive `!isPaid`
/// copy — see that screen's doc comment), `auth`, and `subscription`.
final currentSubscriptionProvider = StreamProvider<Subscription>((ref) {
  final uid = ref.watch(currentUidProvider);
  if (uid == null) return Stream.value(const Subscription(uid: ''));
  return ref.watch(subscriptionRepositoryProvider).watchSubscription(uid);
});
