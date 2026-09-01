import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/errors/failure.dart';
import '../../../core/utils/bd_phone.dart';
import '../../../data/services/worker_api_service.dart';
import 'otp_verification_screen.dart';

/// Step 1-4 of the bdapps subscribe flow: pick an operator, enter a
/// number, request an OTP. This is the only place a phone number is
/// collected — see `OtpVerificationScreen` for the rest.
///
/// The operator picker is UX only. Which operator a number "is" is
/// decided authoritatively by `worker/src/subscription.ts`'s
/// `requestOtp` from the phone number's own digits, independent of
/// whatever's selected here — this screen just gives an early, friendly
/// error if the two obviously don't match, rather than silently sending
/// a mismatched pair to the Worker and letting it reject blind.
class PaywallScreen extends ConsumerStatefulWidget {
  const PaywallScreen({super.key});

  @override
  ConsumerState<PaywallScreen> createState() => _PaywallScreenState();
}

class _PaywallScreenState extends ConsumerState<PaywallScreen> {
  BdOperator _operator = BdOperator.robi;
  final _phoneController = TextEditingController();
  final _workerApi = WorkerApiService();
  String? _errorText;
  bool _submitting = false;

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _requestOtp() async {
    final raw = _phoneController.text.trim();
    final normalized = normalizeBdPhoneNumber(raw);
    final detectedOperator = bdOperatorForNormalizedPhone(normalized);

    if (detectedOperator == null) {
      setState(() => _errorText = 'Enter a valid Robi (018) or Cirkle (016) number.');
      return;
    }
    if (detectedOperator != _operator) {
      setState(
        () => _errorText = 'That looks like a ${detectedOperator.label} number — '
            'select ${detectedOperator.label} above, or enter a ${_operator.label} number.',
      );
      return;
    }

    setState(() {
      _errorText = null;
      _submitting = true;
    });
    try {
      final result = await _workerApi.requestSubscriptionOtp(raw);
      if (!mounted) return;
      final subscribed = await Navigator.of(context).push<bool>(
        MaterialPageRoute(
          builder: (_) => OtpVerificationScreen(phone: raw, referenceNo: result.referenceNo),
        ),
      );
      if (!mounted) return;
      if (subscribed == true) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(const SnackBar(content: Text("You're subscribed! It may take a moment to reflect here.")));
        Navigator.of(context).maybePop();
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(e is Failure ? e.message : 'Something went wrong — please try again.')));
    } finally {
      if (mounted) setState(() => _submitting = false);
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
                    child: Text('Choose your operator', style: text.titleSmall),
                  ),
                  const SizedBox(height: 12),
                  SegmentedButton<BdOperator>(
                    segments: [
                      for (final operator in BdOperator.values)
                        ButtonSegment(value: operator, label: Text('${operator.label} (${operator.prefix})')),
                    ],
                    selected: {_operator},
                    onSelectionChanged: (selection) => setState(() => _operator = selection.first),
                  ),
                  const SizedBox(height: 20),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text('Mobile number', style: text.titleSmall),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _phoneController,
                    keyboardType: TextInputType.phone,
                    decoration: InputDecoration(
                      hintText: '${_operator.prefix}XXXXXXXX',
                      errorText: _errorText,
                      prefixIcon: const Icon(Icons.phone_iphone_rounded),
                    ),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _submitting ? null : _requestOtp,
                      child: _submitting
                          ? const SizedBox(
                              height: 18,
                              width: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Send OTP'),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    // No specific price here deliberately — the actual rate
                    // is whatever's configured on AppsPro's own Pricing tab
                    // for this app, not a number to keep in sync by hand in
                    // Dart source. See docs/ARCHITECTURE.md's bdapps note.
                    'Billed directly to your ${_operator.label} mobile balance. Cancel anytime.',
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
