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
    } on FirebaseException {
      throw const NetworkFailure("Couldn't upload your resume — check your internet and try again.");
    }
  }

  Future<void> deleteResume(String uid) async {
    try {
      await _storage.ref(_pathFor(uid)).delete();
    } on FirebaseException catch (e) {
      // Deleting a resume that's already gone (e.g. a stale doc reference)
      // isn't a real failure — nothing left to remove.
      if (e.code != 'object-not-found') {
        throw const NetworkFailure("Couldn't remove your resume — check your internet and try again.");
      }
    }
  }

  /// A short-lived download URL for reading the resume back — used when
  /// the Worker needs the bytes for resume-tailoring, and for any
  /// "preview my resume" UI.
  Future<String> getDownloadUrl(String uid) async {
    try {
      return await _storage.ref(_pathFor(uid)).getDownloadURL();
    } on FirebaseException {
      throw const NetworkFailure("Couldn't load your resume — check your internet and try again.");
    }
  }
}
