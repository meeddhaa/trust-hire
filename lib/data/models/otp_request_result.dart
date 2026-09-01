/// Result of `/v1/subscription/otp/request` — just enough to drive the OTP
/// screen. `referenceNo` must be passed back unchanged to
/// `/v1/subscription/otp/verify`; nothing about the OTP itself (length,
/// value, expiry) is known or checked client-side — AppsPro/BDApps own
/// that entirely.
class OtpRequestResult {
  const OtpRequestResult({required this.referenceNo, required this.statusDetail});

  final String referenceNo;
  final String statusDetail;

  factory OtpRequestResult.fromJson(Map<String, dynamic> json) {
    return OtpRequestResult(
      referenceNo: json['referenceNo'] as String,
      statusDetail: json['statusDetail'] as String? ?? 'Success',
    );
  }
}
