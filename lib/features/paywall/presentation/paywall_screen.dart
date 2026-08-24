import 'package:flutter/material.dart';
import '../../../core/theme/app_motion.dart';
import 'package:flutter_animate/flutter_animate.dart';

/// Tier comparison + subscribe CTA. The bdapps DCB subscription flow
/// itself (the actual charge + webhook that flips `subscriptions/{uid}`
/// to paid) is step 7 — deliberately not faked here. Tapping "Subscribe"
/// today explains that honestly rather than pretending to charge the
/// user; once step 7 lands, this button starts the real bdapps flow
/// without this screen needing to change.
class PaywallScreen extends StatelessWidget {
  const PaywallScreen({super.key});

  @override
  Widget build(BuildContext context) {
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
                  onPressed: () => _showComingSoon(context),
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

  void _showComingSoon(BuildContext context) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(
          content: Text('bdapps subscription checkout is coming in the next build step.'),
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
