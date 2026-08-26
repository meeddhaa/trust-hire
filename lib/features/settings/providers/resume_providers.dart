import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers/repository_providers.dart';
import '../../../core/providers/session_providers.dart';
import '../../../data/services/worker_api_service.dart';

/// Base64-encodes the picked PDF and writes it straight to the profile
/// doc via `ProfileRepository` — no separate upload/delete calls to a
/// file store, since there isn't one (see "Decision: resume storage,
/// twice reconsidered" in docs/ARCHITECTURE.md).
class ResumeController extends AsyncNotifier<void> {
  @override
  FutureOr<void> build() {}

  /// After a successful upload, also asks Gemini to extract skills AND
  /// work experience from the resume — skills get folded in (only
  /// genuinely new ones, see `ProfileRepository.addSkills`), while work
  /// experience is replaced wholesale (see `UserProfile.workExperience`'s
  /// doc comment for why a replace, not a merge, is correct there). So
  /// match scoring/cross-referencing against listings, and the profile
  /// screen's experience section, both draw on the resume's actual
  /// content, not just whatever was typed in onboarding. Returns the
  /// skills actually added, so the caller can tell the user something
  /// concrete ("added 4 skills") instead of just "done."
  Future<List<String>> uploadResume(Uint8List bytes) async {
    final uid = ref.read(currentUidProvider);
    if (uid == null) return const [];
    state = const AsyncLoading();

    var addedSkills = const <String>[];
    state = await AsyncValue.guard(() async {
      await ref.read(profileRepositoryProvider).setResumeBase64(uid, base64Encode(bytes));
      addedSkills = await _extractAndMergeSkills(uid);
    });
    return addedSkills;
  }

  /// A failed extraction (rate limit, a transient Gemini error) doesn't
  /// undo the upload that already succeeded — the resume is saved either
  /// way; auto-filled skills/experience are a bonus on top, not a
  /// dependency of the upload itself, so failures here are swallowed
  /// rather than surfaced as an upload error. [rethrowOnError] flips that
  /// for the standalone "sync again" action below, where a failure IS the
  /// whole point of the call and needs to reach the user, not be silently
  /// absorbed.
  Future<List<String>> _extractAndMergeSkills(String uid, {bool rethrowOnError = false}) async {
    try {
      final currentSkills = ref.read(currentProfileProvider).valueOrNull?.skills ?? const [];
      final extracted = await WorkerApiService().extractResumeSkills(existingSkills: currentSkills);
      // Work experience always gets set (even to an empty list) — the
      // resume is authoritative for this field, so a resume with no
      // parseable work history correctly clears any stale experience
      // from a previous upload rather than leaving it dangling.
      await ref.read(profileRepositoryProvider).setWorkExperience(uid, extracted.experience);
      if (extracted.skills.isEmpty) return const [];
      return await ref.read(profileRepositoryProvider).addSkills(uid, extracted.skills);
    } catch (e) {
      if (rethrowOnError) rethrow;
      return const [];
    }
  }

  /// Manual re-run of the same extraction `uploadResume` does automatically
  /// — for a resume that predates auto-sync, or after editing skills and
  /// wanting the resume's list folded back in. Unlike the automatic path,
  /// failures here surface as a real error (see [_extractAndMergeSkills]).
  Future<List<String>> syncSkills() async {
    final uid = ref.read(currentUidProvider);
    if (uid == null) return const [];
    state = const AsyncLoading();
    var addedSkills = const <String>[];
    state = await AsyncValue.guard(() async {
      addedSkills = await _extractAndMergeSkills(uid, rethrowOnError: true);
    });
    return addedSkills;
  }

  Future<void> deleteResume() async {
    final uid = ref.read(currentUidProvider);
    if (uid == null) return;
    state = const AsyncLoading();
    state = await AsyncValue.guard(() {
      return ref.read(profileRepositoryProvider).setResumeBase64(uid, null);
    });
  }
}

final resumeControllerProvider = AsyncNotifierProvider<ResumeController, void>(ResumeController.new);
