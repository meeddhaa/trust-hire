import 'dart:typed_data';
import 'package:firebase_storage/firebase_storage.dart';
import '../../core/errors/failure.dart';

/// Uploads a resume PDF to Firebase Storage at `resumes/{uid}/resume.pdf`
/// — always the same filename per user, so a re-upload overwrites rather
/// than accumulating old versions (matches `storage.rules`: owner-only,
/// PDF-only, 10MB cap). Requires the Blaze plan to be enabled on the
/// Firebase project — see "Decision: no Firebase Storage" in
/// docs/ARCHITECTURE.md for why this was skipped originally, and the
/// entry right after it for why it got added back.
class ResumeService {
  ResumeService({FirebaseStorage? storage}) : _storage = storage ?? FirebaseStorage.instance;

  final FirebaseStorage _storage;

  String _pathFor(String uid) => 'resumes/$uid/resume.pdf';

  /// Returns the Storage path (not a download URL — those expire) to save
  /// on the user's profile doc.
  Future<String> uploadResume({required String uid, required Uint8List bytes}) async {
    final path = _pathFor(uid);
    try {
      await _storage.ref(path).putData(bytes, SettableMetadata(contentType: 'application/pdf'));
      return path;
    } on FirebaseException catch (e) {
      throw NetworkFailure(_describe(e, action: 'upload'));
    }
  }

  Future<void> deleteResume(String uid) async {
    try {
      await _storage.ref(_pathFor(uid)).delete();
    } on FirebaseException catch (e) {
      // Deleting a resume that's already gone (e.g. a stale doc reference)
      // isn't a real failure — nothing left to remove.
      if (e.code != 'object-not-found') {
        throw NetworkFailure(_describe(e, action: 'remove'));
      }
    }
  }

  /// A short-lived download URL for reading the resume back — used when
  /// the Worker needs the bytes for resume-tailoring, and for any
  /// "preview my resume" UI.
  Future<String> getDownloadUrl(String uid) async {
    try {
      return await _storage.ref(_pathFor(uid)).getDownloadURL();
    } on FirebaseException catch (e) {
      throw NetworkFailure(_describe(e, action: 'load'));
    }
  }

  /// Blames the actual cause instead of defaulting to "check your
  /// internet" — that message was actively misleading the one time this
  /// was tested against a real device: the failure was Storage not being
  /// enabled on the Firebase project yet (`object-not-found` /
  /// `unknown`/bucket-not-found style codes), not connectivity. There's
  /// no reliable, documented FlutterFire code specifically for "bucket
  /// doesn't exist," so this surfaces the raw code rather than guessing
  /// at a friendlier label that might just as easily be wrong.
  String _describe(FirebaseException e, {required String action}) {
    return "Couldn't $action your resume (${e.code}). "
        'If this keeps happening, ask whoever set up the project to confirm '
        'Firebase Storage is enabled — check your internet only if that checks out.';
  }
}
