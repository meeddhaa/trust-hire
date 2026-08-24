import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/providers/session_providers.dart';
import '../../../data/models/subscription.dart';

/// Shows current subscription state and the unsubscribe action. Reads the
/// real `subscriptions/{uid}` doc (via `currentSubscriptionProvider`) —
/// today that's always free for everyone, since nothing writes a paid
/// subscription until step 7's bdapps webhook exists. The unsubscribe
/// button is wired to call the bdapps API in step 7; until then it's
/// disabled with an explanation rather than faking a cancellation.
class SubscriptionScreen extends ConsumerWidget {
  const SubscriptionScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
                Text(subscription.isPaid ? 'TrustHire Plus' : 'Free plan', style: text.headlineSmall),
                const SizedBox(height: 8),
                Text(_statusLine(subscription), style: text.bodyMedium),
                const SizedBox(height: 28),
                if (!subscription.isPaid)
                  ElevatedButton(
                    onPressed: () => context.push('/paywall'),
                    child: const Text('Upgrade to Plus'),
                  )
                else
                  OutlinedButton(
                    onPressed: null, // enabled once step 7 wires the bdapps unsubscribe call
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
          ? "You're subscribed to TrustHire Plus."
          : 'Renews on ${renews.toLocal().toString().split(' ').first}.';
    }
    return "You're on the free plan — match % and trust badge only.";
  }
}
