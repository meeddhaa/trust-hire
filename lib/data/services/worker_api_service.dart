import '../../core/constants/worker_config.dart';
import '../../core/errors/failure.dart';
import '../../core/network/api_client.dart';
import '../models/job_coach_result.dart';
import '../models/match_result.dart';
import '../models/resume_tailor_result.dart';
import '../models/scam_assessment.dart';
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
        if (listingId != null) 'listingId': listingId,
        if (question != null) 'question': question,
      },
    );
    return JobCoachResult.fromJson(response);
  }
}
