/// Result of `/v1/auth/otp/verify` — a verified bdapps subscription,
/// turned into a Firebase session. `customToken` is exchanged via
/// `FirebaseAuthService.signInWithCustomToken`; `uid` is the deterministic,
/// phone-derived id that session will carry (see `worker/src/bdPhone.ts`'s
/// `uidForPhone`) — returned mainly so the caller can pass it straight to
/// `ProfileRepository` without waiting on `FirebaseAuth`'s own state stream
/// to catch up.
class OtpSignInResult {
  const OtpSignInResult({required this.uid, required this.customToken});

  final String uid;
  final String customToken;

  factory OtpSignInResult.fromJson(Map<String, dynamic> json) {
    return OtpSignInResult(
      uid: json['uid'] as String,
      customToken: json['customToken'] as String,
    );
  }
}
