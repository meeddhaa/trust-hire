import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/providers/session_providers.dart';
import '../../../data/models/subscription.dart';
import '../../auth/providers/auth_providers.dart';

/// View profile after onboarding, sign out, and jump to subscription
/// management. Editing (beyond what onboarding already collects) is a
/// natural follow-up once this and the paywall/subscription flow are both
/// in place — kept out of this pass to avoid duplicating the onboarding
/// form before the fields it touches are stable.
class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = Theme.of(context).textTheme;
    final profileAsync = ref.watch(currentProfileProvider);
    final subscriptionAsync = ref.watch(currentSubscriptionProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: profileAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text(error.toString())),
        data: (profile) {
          if (profile == null) return const SizedBox.shrink();
          return SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(profile.displayName.isEmpty ? profile.email : profile.displayName,
                    style: text.headlineSmall),
                if (profile.headline != null) ...[
                  const SizedBox(height: 4),
                  Text(profile.headline!, style: text.bodyLarge),
                ],
                const SizedBox(height: 16),
                subscriptionAsync.when(
                  loading: () => const SizedBox.shrink(),
                  error: (_, _) => const SizedBox.shrink(),
                  data: (subscription) => _TierBadge(subscription: subscription),
                ),
                const SizedBox(height: 24),

                if (profile.skills.isNotEmpty) ...[
                  Text('Skills', style: text.titleMedium),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [for (final skill in profile.skills) Chip(label: Text(skill))],
                  ),
                  const SizedBox(height: 20),
                ],

                if (profile.yearsOfExperience != null)
                  _InfoRow(label: 'Experience', value: '${profile.yearsOfExperience} years'),
                if (profile.educationLevel != null)
                  _InfoRow(label: 'Education', value: profile.educationLevel!),
                _InfoRow(label: 'Email', value: profile.email),
                const SizedBox(height: 28),

                OutlinedButton(
                  onPressed: () => context.push('/subscription'),
                  child: const Text('Manage subscription'),
                ),
                const SizedBox(height: 10),
                TextButton(
                  onPressed: () => ref.read(authControllerProvider.notifier).signOut(),
                  child: const Text('Sign out'),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _TierBadge extends StatelessWidget {
  const _TierBadge({required this.subscription});

  final Subscription subscription;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isPaid = subscription.isPaid;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: isPaid ? scheme.primary.withValues(alpha: 0.12) : scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: isPaid ? scheme.primary : scheme.outline),
      ),
      child: Text(
        isPaid ? 'TrustHire Plus' : 'Free plan',
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: isPaid ? scheme.primary : scheme.onSurfaceVariant,
            ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 100, child: Text(label, style: text.labelMedium)),
          Expanded(child: Text(value, style: text.bodyMedium)),
        ],
      ),
    );
  }
}
