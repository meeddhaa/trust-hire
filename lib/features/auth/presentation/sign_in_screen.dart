import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/errors/failure.dart';
import '../../../core/theme/app_motion.dart';
import '../../../core/utils/bd_phone.dart';
import '../../../data/services/worker_api_service.dart';
import 'otp_verification_screen.dart';

/// The app's front door — and its only one. There is no email/password or
/// Google sign-in, and no free tier underneath this: a verified bdapps
/// (Robi/Cirkle) subscription IS the account. Picking an operator here is
/// UX only — see `worker/src/subscription.ts`'s `requestOtp`, which
/// re-derives the operator from the phone number itself rather than
/// trusting whatever's selected below.
///
/// Also reached whenever a signed-in user's subscription lapses (see the
/// router's redirect guard in `app_router.dart`) — resubscribing and
/// signing back in are the same action once there's no separate account
/// system to stay signed into through a lapse.
class SignInScreen extends ConsumerStatefulWidget {
  const SignInScreen({super.key});

  @override
  ConsumerState<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends ConsumerState<SignInScreen> {
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
      final result = await _workerApi.requestAuthOtp(raw);
      if (!mounted) return;
      await Navigator.of(context).push<bool>(
        MaterialPageRoute(
          builder: (_) => OtpVerificationScreen(phone: raw, referenceNo: result.referenceNo),
        ),
      );
      // No further action needed on return: a successful verify already
      // signed the user in (see OtpVerificationScreen), and the router's
      // authStateProvider listener redirects away from here on its own.
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
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 32),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Trust Hire', style: text.displaySmall)
                      .animate()
                      .fadeIn(duration: AppMotion.standard)
                      .slideY(begin: 0.15, end: 0, curve: AppMotion.settle),
                  const SizedBox(height: 6),
                  Text(
                    'Log in with your Robi or Cirkle number to see how you match, '
                    'and which listings to trust.',
                    style: text.bodyLarge,
                  ).animate().fadeIn(delay: AppMotion.fast, duration: AppMotion.standard),
                  const SizedBox(height: 32),

                  Text('Choose your operator', style: text.titleSmall),
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

                  Text('Mobile number', style: text.titleSmall),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _phoneController,
                    keyboardType: TextInputType.phone,
                    autofillHints: const [AutofillHints.telephoneNumber],
                    decoration: InputDecoration(
                      hintText: '${_operator.prefix}XXXXXXXX',
                      errorText: _errorText,
                      prefixIcon: const Icon(Icons.phone_iphone_rounded),
                    ),
                    onSubmitted: (_) => _requestOtp(),
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
                  ),
                  const SizedBox(height: 16),
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
