import 'dart:convert';
import 'package:http/http.dart' as http;
import '../errors/failure.dart';

/// Thin, reusable HTTP wrapper: JSON POST with a bearer token, and one
/// place that maps HTTP status codes to [Failure]s. `worker_api_service.dart`
/// is the only current caller (the bdapps API in step 7 will be the
/// second), so this stays generic rather than baking in Worker-specific
/// paths or response shapes.
class ApiClient {
  ApiClient({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  /// POSTs [body] as JSON to `baseUrl + path`, and returns the decoded
  /// JSON response body. [bearerToken] is sent as `Authorization: Bearer
  /// $bearerToken` when given; `null` for the handful of pre-auth Worker
  /// routes (the bdapps sign-in OTP endpoints — see
  /// `WorkerApiService.requestAuthOtp`/`verifyAuthOtp`) that run before
  /// any Firebase session exists to send a token for.
  ///
  /// Throws a [Failure] subtype for every non-2xx response and for
  /// network-level errors (timeout, no connectivity, unreachable host) —
  /// callers never need to inspect a raw [http.Response] or status code.
  Future<Map<String, dynamic>> postJson(
    String baseUrl,
    String path, {
    String? bearerToken,
    required Map<String, dynamic> body,
  }) async {
    final http.Response response;
    try {
      response = await _client
          .post(
            Uri.parse('$baseUrl$path'),
            headers: {
              if (bearerToken != null) 'Authorization': 'Bearer $bearerToken',
              'Content-Type': 'application/json',
            },
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 30));
    } on Exception {
      // Covers SocketException (no connectivity), TimeoutException, and
      // any TLS/handshake failure http.Client surfaces as an Exception.
      throw const NetworkFailure();
    }

    final Map<String, dynamic> decoded;
    try {
      decoded = jsonDecode(response.body) as Map<String, dynamic>;
    } on FormatException {
      throw const ServerFailure('Received an unreadable response — please try again.');
    }

    if (response.statusCode >= 200 && response.statusCode < 300) return decoded;

    final serverMessage = decoded['error'] as String?;
    throw switch (response.statusCode) {
      401 || 403 => AuthFailure(serverMessage ?? 'Please sign in again.'),
      404 => NotFoundFailure(serverMessage ?? const NotFoundFailure().message),
      429 => RateLimitFailure(serverMessage ?? const RateLimitFailure().message),
      >= 500 => ServerFailure(serverMessage ?? const ServerFailure().message),
      _ => UnknownFailure(serverMessage ?? const UnknownFailure().message),
    };
  }
}
