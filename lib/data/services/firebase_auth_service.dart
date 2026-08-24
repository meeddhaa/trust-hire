import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../../core/errors/failure.dart';

/// Thin wrapper around `firebase_auth` + `google_sign_in` — the only place
/// in the app that touches those SDKs directly. Maps every failure mode
/// to a [Failure] so callers (Riverpod notifiers) never handle
/// [FirebaseAuthException] themselves.
class FirebaseAuthService {
  FirebaseAuthService({FirebaseAuth? auth, GoogleSignIn? googleSignIn})
      : _auth = auth ?? FirebaseAuth.instance,
        _googleSignIn = googleSignIn ?? GoogleSignIn();

  final FirebaseAuth _auth;
  final GoogleSignIn _googleSignIn;

  User? get currentUser => _auth.currentUser;

  Stream<User?> authStateChanges() => _auth.authStateChanges();

  /// The Firebase ID token for the current user, or `null` if signed out.
  /// This is what every Worker call sends as `Authorization: Bearer ...`
  /// — see `worker_api_service.dart`.
  Future<String?> getIdToken() => _auth.currentUser?.getIdToken() ?? Future.value(null);

  Future<User> signUpWithEmail({required String email, required String password}) async {
    try {
      final credential = await _auth.createUserWithEmailAndPassword(email: email, password: password);
      return credential.user!;
    } on FirebaseAuthException catch (e) {
      throw AuthFailure(_messageFor(e));
    }
  }

  Future<User> signInWithEmail({required String email, required String password}) async {
    try {
      final credential = await _auth.signInWithEmailAndPassword(email: email, password: password);
      return credential.user!;
    } on FirebaseAuthException catch (e) {
      throw AuthFailure(_messageFor(e));
    }
  }

  /// Returns `null` if the user cancels the Google account picker — that's
  /// a normal outcome, not a failure, so callers shouldn't show an error.
  Future<User?> signInWithGoogle() async {
    try {
      final account = await _googleSignIn.signIn();
      if (account == null) return null;

      final googleAuth = await account.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );
      final userCredential = await _auth.signInWithCredential(credential);
      return userCredential.user;
    } on FirebaseAuthException catch (e) {
      throw AuthFailure(_messageFor(e));
    }
  }

  Future<void> signOut() async {
    await Future.wait([_auth.signOut(), _googleSignIn.signOut()]);
  }

  /// Translates the common Firebase Auth error codes into copy a user can
  /// act on. Falls back to Firebase's own message for anything less common
  /// rather than guessing at every possible code.
  String _messageFor(FirebaseAuthException e) {
    return switch (e.code) {
      'invalid-email' => 'That email address looks invalid.',
      'user-disabled' => 'This account has been disabled.',
      'user-not-found' || 'wrong-password' || 'invalid-credential' =>
        'Incorrect email or password.',
      'email-already-in-use' => 'An account already exists with that email.',
      'weak-password' => 'Choose a stronger password (at least 6 characters).',
      'network-request-failed' => 'Connection problem — check your internet and try again.',
      'too-many-requests' => 'Too many attempts — please wait a moment and try again.',
      _ => e.message ?? 'Sign-in failed — please try again.',
    };
  }
}
