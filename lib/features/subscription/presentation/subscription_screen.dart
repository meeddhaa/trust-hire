import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/providers/session_providers.dart';
import '../../../data/models/subscription.dart';
import '../../../data/services/worker_api_service.dart';

/// Shows current subscription state and the unsubscribe action. Reads the
/// real `subscriptions/{uid}` doc (via `currentSubscriptionProvider`, a
/// live Firestore stream) — written only by the Worker, either right after
/// a successful OTP sign-in (`worker/src/subscription.ts`) or by the
/// AppsPro webhook (`worker/src/appspro.ts`) for events this app didn't
/// directly cause. The unsubscribe button stays disabled until bdapps'
/// own unsubscribe endpoint is wired up rather than faking a cancellation.
///
/// There's no "Upgrade to Plus" here — there's no free tier at all (see
/// `SignInScreen`'s doc comment: a verified subscription IS the account),
/// so `isPaid` should always read true by the time anyone reaches this
/// screen; the router's redirect guard sends anyone whose subscription
/// lapses straight back to `/sign-in` instead. The `!isPaid` branch below
/// is defensive only — a brief render before that redirect catches up —
/// and offers "Resubscribe" rather than a button pointing at a deleted
/// paywall route.
class SubscriptionScreen extends ConsumerStatefulWidget {
  const SubscriptionScreen({super.key});

  @override
  ConsumerState<SubscriptionScreen> createState() => _SubscriptionScreenState();
}

class _SubscriptionScreenState extends ConsumerState<SubscriptionScreen> {
  @override
  void initState() {
    super.initState();
    // "Verify the subscription when appropriate rather than permanently
    // trusting a local boolean" — opening this screen is exactly that
    // moment. Silent and best-effort: the live Firestore stream above is
    // already the screen's real source of truth, so a failed refresh
    // (offline, AppsPro down) just leaves the last-known state on screen
    // instead of surfacing an error for a background reconciliation call.
    final uid = ref.read(currentUidProvider);
    if (uid != null) _silentlyRefresh(uid);
  }

  Future<void> _silentlyRefresh(String uid) async {
    try {
      await WorkerApiService().refreshSubscriptionStatus(uid: uid);
    } catch (_) {
      // Best-effort — see initState's doc comment.
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final subscriptionAsync = ref.watch(currentSubscriptionProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Subscription')),
      body: subscriptionAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text(error.toString())),
        data: (subscription) {
          return Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Trust Hire', style: text.headlineSmall),
                const SizedBox(height: 8),
                Text(_statusLine(subscription), style: text.bodyMedium),
                const SizedBox(height: 28),
                if (!subscription.isPaid)
                  ElevatedButton(
                    onPressed: () => context.go('/sign-in'),
                    child: const Text('Resubscribe'),
                  )
                else
                  OutlinedButton(
                    onPressed: null, // enabled once bdapps' own unsubscribe endpoint is wired up
                    child: const Text('Unsubscribe'),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  String _statusLine(Subscription subscription) {
    if (subscription.isPaid) {
      final renews = subscription.renewsAt;
      return renews == null
          ? "You're subscribed via bdapps."
          : 'Renews on ${renews.toLocal().toString().split(' ').first}.';
    }
    return 'Your subscription needs to be renewed to keep using Trust Hire.';
  }
}
