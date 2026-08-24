/// Typed failures surfaced to the UI layer, so a screen can pattern-match
/// on `switch (failure) { ... }` instead of parsing exception messages or
/// HTTP status codes itself. Repositories/services catch raw exceptions
/// (`FirebaseAuthException`, `http` errors, JSON decode errors) and
/// `throw` one of these instead — providers built on `FutureProvider`/
/// `AsyncNotifier` capture it automatically into `AsyncValue.error`, so a
/// screen just does `error is Failure ? error.message : "..."`. Implements
/// `Exception` so `throw` reads naturally at call sites.
sealed class Failure implements Exception {
  const Failure(this.message);

  /// Plain-language, safe to show directly in a snackbar/dialog.
  final String message;

  @override
  String toString() => message;
}

/// No connectivity, timeout, or a non-JSON/unreachable response.
final class NetworkFailure extends Failure {
  const NetworkFailure([super.message = 'Connection problem — check your internet and try again.']);
}

/// Sign-in/sign-up failed, or a Worker call's auth token was rejected.
final class AuthFailure extends Failure {
  const AuthFailure(super.message);
}

/// The Worker returned 404 — a listing or profile that should exist doesn't.
final class NotFoundFailure extends Failure {
  const NotFoundFailure([super.message = "That listing isn't available anymore."]);
}

/// The Worker's per-user daily AI quota was hit (HTTP 429).
final class RateLimitFailure extends Failure {
  const RateLimitFailure([super.message = "You've hit today's AI request limit — try again tomorrow."]);
}

/// Gemini itself failed (HTTP 502 from the Worker) or any other
/// unexpected server-side error.
final class ServerFailure extends Failure {
  const ServerFailure([super.message = 'Something went wrong on our end — please try again.']);
}

/// Fallback for anything that doesn't map to a more specific case.
final class UnknownFailure extends Failure {
  const UnknownFailure([super.message = 'Something unexpected happened.']);
}
