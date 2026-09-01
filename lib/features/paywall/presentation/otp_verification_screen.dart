import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/errors/failure.dart';
import '../../../core/providers/session_providers.dart';
import '../../../data/services/worker_api_service.dart';

/// Step 5-9 of the bdapps subscribe flow: the user enters the OTP AppsPro/
/// BDApps just sent as a real SMS (see `PaywallScreen`, which pushes this
/// screen after a successful `/v1/subscription/otp/request`). Nothing here
/// generates, validates, or auto-accepts an OTP locally — every attempt
/// round-trips to `worker/src/subscription.ts`'s `verifyOtpAndActivate`,
/// which is also where paid access actually gets granted, only once
/// AppsPro/BDApps confirm both the OTP AND the resulting subscription are
/// genuinely valid.
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
    final uid = ref.read(currentUidProvider);
    if (uid == null) return;

    setState(() {
      _verifying = true;
      _errorText = null;
    });
    try {
      await _workerApi.verifySubscriptionOtp(uid: uid, referenceNo: _referenceNo, otp: otp);
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
      final result = await _workerApi.requestSubscriptionOtp(widget.phone);
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
