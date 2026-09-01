import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'appspro_checkout_screen.dart';

/// Subscribe screen — deliberately just icon, copy, one button. Tapping
/// "Subscribe with OTP" goes straight into `AppsProCheckoutScreen`; there's
/// no phone-number field here at all. AppsPro's own WebSDK widget is the
/// only place a phone number is ever typed, and its `success` event is
/// what hands the number back to this app (see that screen's doc comment
/// for why collecting it here first turned out to be the wrong approach —
/// double entry, and a widget-embed hosts the OTP form better anyway).
class PaywallScreen extends ConsumerWidget {
  const PaywallScreen({super.key});

  Future<void> _subscribe(BuildContext context) async {
    final subscribed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => const AppsProCheckoutScreen()),
    );
    if (subscribed == true && context.mounted) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(content: Text("You're subscribed! It may take a moment to reflect here.")));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Subscribe')),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
              child: Column(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: Image.asset('assets/icon/icon_base.png', width: 72, height: 72),
                  ),
                  const SizedBox(height: 16),
                  Text('Trust Hire', style: text.titleLarge),
                  const SizedBox(height: 6),
                  Text(
                    'Get the full match breakdown and skill roadmap.',
                    style: text.bodyMedium,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 32),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () => _subscribe(context),
                      child: const Text('Subscribe with OTP'),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    'This app charges via Robi/Airtel ৳2.00 (incl. VAT) daily. Cancel anytime.',
                    style: text.bodySmall,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Powered by AppsPro',
                    style: text.labelSmall?.copyWith(color: scheme.onSurfaceVariant),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
