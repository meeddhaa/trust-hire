import '../../core/constants/worker_config.dart';
import '../../core/errors/failure.dart';
import '../../core/network/api_client.dart';
import '../models/job_coach_result.dart';
import '../models/match_result.dart';
import '../models/otp_request_result.dart';
import '../models/otp_sign_in_result.dart';
import '../models/resume_extraction_result.dart';
import '../models/resume_tailor_result.dart';
import '../models/scam_assessment.dart';
import '../models/subscription.dart';
import 'firebase_auth_service.dart';

/// Calls the Cloudflare Worker's two AI endpoints. The Worker's response
/// JSON uses the same field names as `MatchResult`/`ScamAssessment`'s
/// Firestore representation (`computedAt` as an ISO string instead of a
/// `Timestamp`, everything else identical), so their existing `fromMap`
/// constructors parse it directly — see `core/utils/firestore_codec.dart`'s
/// `dateTimeFromValue`, which already handles a `String` date.
class WorkerApiService {
  WorkerApiService({ApiClient? apiClient, FirebaseAuthService? authService})
      : _apiClient = apiClient ?? ApiClient(),
        _authService = authService ?? FirebaseAuthService();

  final ApiClient _apiClient;
  final FirebaseAuthService _authService;

  Future<String> _requireIdToken() async {
    final token = await _authService.getIdToken();
    if (token == null) throw const AuthFailure('Please sign in to continue.');
    return token;
  }

  Future<MatchResult> fetchMatch(String listingId) async {
    final token = await _requireIdToken();
    final response = await _apiClient.postJson(
      WorkerConfig.baseUrl,
      WorkerConfig.matchPath,
      bearerToken: token,
      body: {'listingId': listingId},
    );
    return MatchResult.fromMap(response, id: response['id'] as String);
  }

  Future<ScamAssessment> fetchScamAssessment(String listingId) async {
    final token = await _requireIdToken();
    final response = await _apiClient.postJson(
      WorkerConfig.baseUrl,
      WorkerConfig.scamAssessmentPath,
      bearerToken: token,
      body: {'listingId': listingId},
    );
    return ScamAssessment.fromMap(response, listingId: response['listingId'] as String);
  }

  /// Throws [NotFoundFailure] (via [ApiClient]) if the user hasn't
  /// uploaded a resume yet — the caller (see `resume_tailor_providers.dart`)
  /// treats that as "prompt them to upload one," not an error state.
  Future<ResumeTailorResult> fetchResumeTailoring(String listingId) async {
    final token = await _requireIdToken();
    final response = await _apiClient.postJson(
      WorkerConfig.baseUrl,
      WorkerConfig.resumeTailorPath,
      bearerToken: token,
      body: {'listingId': listingId},
    );
    return ResumeTailorResult.fromJson(response);
  }

  /// `listingId` and `question` are both optional — the Worker uses
  /// whatever context is available (profile always, listing/resume if
  /// present) rather than requiring a fixed shape per intent.
  Future<JobCoachResult> askJobCoach({required String intent, String? listingId, String? question}) async {
    final token = await _requireIdToken();
    final response = await _apiClient.postJson(
      WorkerConfig.baseUrl,
      WorkerConfig.jobCoachPath,
      bearerToken: token,
      body: {
        'intent': intent,
        'listingId': ?listingId,
        'question': ?question,
      },
    );
    return JobCoachResult.fromJson(response);
  }

  /// Throws [NotFoundFailure] (via [ApiClient]) if no resume is on file —
  /// callers should only invoke this right after a successful upload,
  /// where that shouldn't happen.
  Future<ResumeExtractionResult> extractResumeSkills({required List<String> existingSkills}) async {
    final token = await _requireIdToken();
    final response = await _apiClient.postJson(
      WorkerConfig.baseUrl,
      WorkerConfig.resumeSkillsPath,
      bearerToken: token,
      body: {'existingSkills': existingSkills},
    );
    return ResumeExtractionResult.fromJson(response);
  }

  /// Sends a real OTP SMS via AppsPro/BDApps to [rawPhone] — no local OTP
  /// generation happens anywhere in this app. No ID token is sent (see
  /// `ApiClient.postJson`): this is the first step of signing in, so there
  /// is no session yet to send a token for. Throws (via [ApiClient]) if
  /// the number isn't a supported operator (Robi/Cirkle) or if AppsPro
  /// itself rejects the request (e.g. its own rate limit) — see
  /// `worker/src/subscription.ts`'s `requestOtp` for what's actually
  /// enforced server-side; this call carries no operator field of its own,
  /// deliberately, since the Worker re-derives it from the phone number
  /// itself rather than trusting anything the client claims.
  Future<OtpRequestResult> requestAuthOtp(String rawPhone) async {
    final response = await _apiClient.postJson(
      WorkerConfig.baseUrl,
      WorkerConfig.authOtpRequestPath,
      body: {'phone': rawPhone},
    );
    return OtpRequestResult.fromJson(response);
  }

  /// Verifies the OTP with AppsPro/BDApps and, only if that ALSO passes an
  /// independent subscription-status check server-side, mints a Firebase
  /// custom token for the resulting (phone-derived) uid — see
  /// `worker/src/subscription.ts`'s `verifyOtpAndSignIn`. The caller still
  /// has to exchange [OtpSignInResult.customToken] via
  /// `FirebaseAuthService.signInWithCustomToken` to actually be signed in;
  /// this call alone doesn't do that. Throws a [Failure] for a wrong/
  /// expired OTP, a rate limit, or a subscription that still can't be
  /// confirmed active even after OTP verification succeeds — never
  /// silently grants access on the client's own say-so.
  Future<OtpSignInResult> verifyAuthOtp({required String referenceNo, required String otp}) async {
    final response = await _apiClient.postJson(
      WorkerConfig.baseUrl,
      WorkerConfig.authOtpVerifyPath,
      body: {'referenceNo': referenceNo, 'otp': otp},
    );
    return OtpSignInResult.fromJson(response);
  }

  /// Re-checks the current subscription's live status with AppsPro rather
  /// than trusting whatever `subscriptions/{uid}` last said — see
  /// `SubscriptionScreen`, which calls this once when opened. A no-op
  /// server-side (returns the existing doc unchanged) for anyone who has
  /// never subscribed.
  Future<Subscription> refreshSubscriptionStatus({required String uid}) async {
    final token = await _requireIdToken();
    final response = await _apiClient.postJson(
      WorkerConfig.baseUrl,
      WorkerConfig.subscriptionRefreshPath,
      bearerToken: token,
      body: const {},
    );
    return Subscription.fromMap(response, uid: uid);
  }
}
