import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers/repository_providers.dart';
import '../../../core/providers/session_providers.dart';
import '../../../core/theme/app_motion.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../core/utils/bd_phone.dart';
import 'appspro_checkout_screen.dart';

/// Tier comparison + subscribe CTA. Tapping "Subscribe via bdapps" opens
/// AppsPro's hosted checkout (OTP-verified BD phone subscription) — see
/// `appspro_checkout_screen.dart` and `worker/src/appspro.ts` for the two
/// halves of that flow. A phone number is collected first if the profile
/// doesn't have one yet: it's the only join key AppsPro's webhook can
/// hand back (see `UserProfile.phoneNumber`'s doc comment), so checkout
/// can't proceed without it.
class PaywallScreen extends ConsumerWidget {
  const PaywallScreen({super.key});

  Future<void> _subscribe(BuildContext context, WidgetRef ref) async {
    final uid = ref.read(currentUidProvider);
    if (uid == null) return;
    final existingPhone = ref.read(currentProfileProvider).valueOrNull?.phoneNumber;

    if (existingPhone == null) {
      final phone = await _promptForPhone(context);
      if (phone == null) return;
      if (!context.mounted) return;
      try {
        await ref.read(profileRepositoryProvider).setPhoneNumber(uid, phone);
      } catch (e) {
        if (!context.mounted) return;
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text('$e')));
        return;
      }
    }

    if (!context.mounted) return;
    final subscribed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => const AppsProCheckoutScreen()),
    );
    if (subscribed == true && context.mounted) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(content: Text("You're subscribed! It may take a moment to reflect here.")));
    }
  }

  Future<String?> _promptForPhone(BuildContext context) async {
    final controller = TextEditingController();
    String? errorText;
    return showDialog<String>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setState) => AlertDialog(
          title: const Text('Your phone number'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Needed for bdapps direct carrier billing — one Bangladeshi mobile number per subscription.'),
              const SizedBox(height: 12),
              TextField(
                controller: controller,
                autofocus: true,
                keyboardType: TextInputType.phone,
                decoration: InputDecoration(hintText: '01XXXXXXXXX', errorText: errorText),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Cancel')),
            TextButton(
              onPressed: () {
                final value = controller.text.trim();
                if (!isPlausibleBdPhoneNumber(value)) {
                  setState(() => errorText = "That doesn't look like a valid Bangladeshi mobile number.");
                  return;
                }
                Navigator.pop(dialogContext, value);
              },
              child: const Text('Continue'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(title: const Text('TrustHire Plus')),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
              children: [
                Text('See the full picture', style: text.headlineMedium)
                    .animate()
                    .fadeIn(duration: AppMotion.standard)
                    .slideY(begin: 0.1, end: 0, curve: AppMotion.settle),
                const SizedBox(height: 6),
                Text(
                  'Free shows you the score. Plus shows you why — and what to do about it.',
                  style: text.bodyLarge,
                ),
                const SizedBox(height: 28),

                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: _TierCard(
                      title: 'Free',
                      price: '৳0',
                      features: const ['Match percentage', 'Trust badge', 'Rule-based risk flags'],
                      highlighted: false,
                    )),
                    const SizedBox(width: 12),
                    Expanded(child: _TierCard(
                      title: 'Plus',
                      price: '৳149/mo',
                      features: const [
                        'Everything in Free',
                        'Full gap breakdown',
                        'Personalized upskilling roadmap',
                        'Full scam-risk reasoning',
                      ],
                      highlighted: true,
                    )),
                  ],
                ),
                const SizedBox(height: 28),

                ElevatedButton(
                  onPressed: () => _subscribe(context, ref),
                  child: const Text('Subscribe via bdapps'),
                ),
                const SizedBox(height: 8),
                Text(
                  'Billed through your bdapps account (direct carrier billing) — '
                  'cancel anytime from Manage Subscription.',
                  style: text.bodySmall,
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TierCard extends StatelessWidget {
  const _TierCard({
    required this.title,
    required this.price,
    required this.features,
    required this.highlighted,
  });

  final String title;
  final String price;
  final List<String> features;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: highlighted ? scheme.primary.withValues(alpha: 0.06) : scheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: highlighted ? scheme.primary : scheme.outline, width: highlighted ? 1.5 : 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: text.titleLarge),
          const SizedBox(height: 2),
          Text(price, style: text.headlineSmall),
          const SizedBox(height: 12),
          for (final feature in features)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.check_rounded, size: 16, color: highlighted ? scheme.primary : scheme.onSurfaceVariant),
                  const SizedBox(width: 6),
                  Expanded(child: Text(feature, style: text.bodySmall)),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
