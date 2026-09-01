import 'package:firebase_auth/firebase_auth.dart';
import '../../core/errors/failure.dart';

/// Thin wrapper around `firebase_auth` — the only place in the app that
/// touches that SDK directly. Maps every failure mode to a [Failure] so
/// callers (Riverpod notifiers) never handle [FirebaseAuthException]
/// themselves.
///
/// There is exactly one way into this app now: a verified bdapps
/// subscription, via [signInWithCustomToken] — see `SignInScreen` and
/// `worker/src/subscription.ts`'s `verifyOtpAndSignIn`/`firebaseCustomToken.ts`.
/// Email/password and Google sign-in were removed entirely rather than
/// kept alongside it; there's no separate account system for a phone
/// number to link into, and the class already carried no reachable UI
/// for either by the time this had to change.
class FirebaseAuthService {
  FirebaseAuthService({FirebaseAuth? auth}) : _auth = auth ?? FirebaseAuth.instance;

  final FirebaseAuth _auth;

  User? get currentUser => _auth.currentUser;

  Stream<User?> authStateChanges() => _auth.authStateChanges();

  /// The Firebase ID token for the current user, or `null` if signed out.
  /// This is what every Worker call sends as `Authorization: Bearer ...`
  /// — see `worker_api_service.dart`.
  Future<String?> getIdToken() => _auth.currentUser?.getIdToken() ?? Future.value(null);

  /// Exchanges a Worker-minted Firebase custom token
  /// (`OtpSignInResult.customToken`) for a real, auto-refreshing Firebase
  /// Auth session — the one and only sign-in path this app has. The
  /// resulting [User] carries no `email`/`displayName` (custom tokens
  /// don't set either); `UserProfile.friendlyUsername` falls back to the
  /// phone number for exactly that reason.
  Future<User> signInWithCustomToken(String token) async {
    try {
      final credential = await _auth.signInWithCustomToken(token);
      return credential.user!;
    } on FirebaseAuthException catch (e) {
      throw AuthFailure(_messageFor(e));
    }
  }

  Future<void> signOut() async {
    await _auth.signOut();
  }

  /// Deletes the Firebase Auth account itself. Callers should delete
  /// owned Firestore/Storage data *before* calling this (see
  /// `AccountController.deleteAccount`), and once signed out there's no
  /// user to authorize those deletes with.
  ///
  /// Firebase requires a "recent" sign-in for this; if the session is
  /// older than a few minutes this throws `requires-recent-login`, which
  /// is surfaced as a specific, actionable message rather than a generic
  /// re-auth flow (re-running the OTP sign-in) — deferred as a fast-follow
  /// rather than built now.
  Future<void> deleteAccount() async {
    final user = _auth.currentUser;
    if (user == null) return;
    try {
      await user.delete();
    } on FirebaseAuthException catch (e) {
      if (e.code == 'requires-recent-login') {
        throw const AuthFailure('Please sign out and sign back in, then try deleting your account again.');
      }
      throw AuthFailure(_messageFor(e));
    }
  }

  /// Translates the common Firebase Auth error codes into copy a user can
  /// act on. Falls back to Firebase's own message for anything less common
  /// rather than guessing at every possible code.
  String _messageFor(FirebaseAuthException e) {
    return switch (e.code) {
      'invalid-custom-token' => 'Sign-in failed — please try again.',
      'custom-token-mismatch' => 'Sign-in failed — please try again.',
      'user-disabled' => 'This account has been disabled.',
      'network-request-failed' => 'Connection problem — check your internet and try again.',
      'too-many-requests' => 'Too many attempts — please wait a moment and try again.',
      _ => e.message ?? 'Sign-in failed — please try again.',
    };
  }
}
