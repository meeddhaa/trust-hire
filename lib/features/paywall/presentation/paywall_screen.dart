import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers/repository_providers.dart';
import '../../../core/providers/session_providers.dart';
import '../../../core/utils/bd_phone.dart';
import 'appspro_checkout_screen.dart';

/// Subscribe screen — deliberately just phone number in, OTP checkout out,
/// matching AppsPro's own hosted-checkout pages (see the "Notes CT"
/// reference screenshot): icon, one line of copy, a phone field, one
/// button, the price disclaimer, done. No tier comparison — there's only
/// one tier, priced entirely on AppsPro's side (see its Pricing tab).
///
/// A phone number is collected here (or reused from the profile if already
/// set) because it's the only join key AppsPro's webhook can hand back —
/// see `UserProfile.phoneNumber`'s doc comment and `worker/src/appspro.ts`.
class PaywallScreen extends ConsumerStatefulWidget {
  const PaywallScreen({super.key});

  @override
  ConsumerState<PaywallScreen> createState() => _PaywallScreenState();
}

class _PaywallScreenState extends ConsumerState<PaywallScreen> {
  final _phoneController = TextEditingController();
  String? _errorText;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    final existingPhone = ref.read(currentProfileProvider).valueOrNull?.phoneNumber;
    if (existingPhone != null) _phoneController.text = existingPhone;
  }

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _subscribe() async {
    final uid = ref.read(currentUidProvider);
    if (uid == null) return;
    final value = _phoneController.text.trim();
    if (!isPlausibleBdPhoneNumber(value)) {
      setState(() => _errorText = "That doesn't look like a valid Robi or Airtel number.");
      return;
    }

    setState(() {
      _errorText = null;
      _submitting = true;
    });
    try {
      await ref.read(profileRepositoryProvider).setPhoneNumber(uid, value);
    } catch (e) {
      if (!mounted) return;
      setState(() => _submitting = false);
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text('$e')));
      return;
    }
    if (!mounted) return;
    setState(() => _submitting = false);

    final subscribed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => const AppsProCheckoutScreen()),
    );
    if (subscribed == true && mounted) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(content: Text("You're subscribed! It may take a moment to reflect here.")));
    }
  }

  @override
  Widget build(BuildContext context) {
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
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text('Log in with your Robi or Airtel number', style: text.titleSmall),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _phoneController,
                    keyboardType: TextInputType.phone,
                    decoration: InputDecoration(
                      hintText: '01XXXXXXXXX',
                      errorText: _errorText,
                      prefixIcon: const Icon(Icons.phone_iphone_rounded),
                    ),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _submitting ? null : _subscribe,
                      child: _submitting
                          ? const SizedBox(
                              height: 18,
                              width: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Subscribe with OTP'),
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
