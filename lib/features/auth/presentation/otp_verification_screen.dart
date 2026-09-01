import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/errors/failure.dart';
import '../../../core/providers/repository_providers.dart';
import '../../../data/services/firebase_auth_service.dart';
import '../../../data/services/worker_api_service.dart';

/// The rest of the bdapps sign-in flow: the user enters the OTP AppsPro/
/// BDApps just sent as a real SMS (see `SignInScreen`, which pushes this
/// screen after a successful `/v1/auth/otp/request`). Nothing here
/// generates, validates, or auto-accepts an OTP locally — every attempt
/// round-trips to `worker/src/subscription.ts`'s `verifyOtpAndSignIn`,
/// which independently confirms the resulting subscription is genuinely
/// active before minting anything.
///
/// A successful verify returns a Firebase custom token, not a session by
/// itself — [_verify] still has to exchange it
/// (`FirebaseAuthService.signInWithCustomToken`) and ensure the Firestore
/// profile exists before this screen pops. Only once all of that has
/// happened does `authStateProvider` flip and the router take the user
/// off `/sign-in` on its own.
class OtpVerificationScreen extends ConsumerStatefulWidget {
  const OtpVerificationScreen({super.key, required this.phone, required this.referenceNo});

  final String phone;
  final String referenceNo;

  @override
  ConsumerState<OtpVerificationScreen> createState() => _OtpVerificationScreenState();
}

class _OtpVerificationScreenState extends ConsumerState<OtpVerificationScreen> {
  final _otpController = TextEditingController();
  final _workerApi = WorkerApiService();
  final _authService = FirebaseAuthService();

  // Reassigned on resend — every verify attempt must use whichever
  // reference_no was issued most recently, not necessarily the one this
  // screen was first pushed with.
  late String _referenceNo = widget.referenceNo;

  bool _verifying = false;
  bool _resending = false;
  String? _errorText;

  @override
  void dispose() {
    _otpController.dispose();
    super.dispose();
  }

  Future<void> _verify() async {
    final otp = _otpController.text.trim();
    if (otp.isEmpty) {
      setState(() => _errorText = 'Enter the code you were sent.');
      return;
    }

    setState(() {
      _verifying = true;
      _errorText = null;
    });
    try {
      final signInResult = await _workerApi.verifyAuthOtp(referenceNo: _referenceNo, otp: otp);
      final user = await _authService.signInWithCustomToken(signInResult.customToken);
      // A custom-token session carries no email/displayName, so the
      // profile doc has to be created (or found, for a returning number)
      // and have its phone number set explicitly — the same two calls
      // the old email/password flow made after its own sign-in, just
      // with the phone number this flow already collected instead of
      // pulling it off the FirebaseUser.
      await ref.read(profileRepositoryProvider).ensureProfileExists(user);
      await ref.read(profileRepositoryProvider).setPhoneNumber(signInResult.uid, widget.phone);
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _verifying = false;
        _errorText = e is Failure ? e.message : 'Something went wrong — please try again.';
      });
    }
  }

  Future<void> _resend() async {
    setState(() {
      _resending = true;
      _errorText = null;
    });
    try {
      final result = await _workerApi.requestAuthOtp(widget.phone);
      if (!mounted) return;
      setState(() {
        _referenceNo = result.referenceNo;
        _resending = false;
      });
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(content: Text('A new code has been sent.')));
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _resending = false;
        _errorText = e is Failure ? e.message : 'Something went wrong — please try again.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Enter OTP')),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Enter the code sent to ${widget.phone}',
                    style: text.titleMedium,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  TextField(
                    controller: _otpController,
                    keyboardType: TextInputType.number,
                    textAlign: TextAlign.center,
                    style: text.headlineSmall,
                    decoration: InputDecoration(hintText: '••••', errorText: _errorText),
                    onSubmitted: (_) => _verify(),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _verifying ? null : _verify,
                      child: _verifying
                          ? const SizedBox(
                              height: 18,
                              width: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Verify'),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextButton(
                    onPressed: _resending ? null : _resend,
                    child: Text(_resending ? 'Resending…' : "Didn't get it? Resend OTP"),
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
