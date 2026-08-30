import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers/repository_providers.dart';
import '../../../core/providers/session_providers.dart';
import '../../../data/models/resume.dart';
import '../../../data/services/worker_api_service.dart';

/// The user's named resumes (`users/{uid}/resumes/*`) — see `Resume`'s
/// doc comment for the "exactly one active" design.
final resumesStreamProvider = StreamProvider<List<Resume>>((ref) {
  final uid = ref.watch(currentUidProvider);
  if (uid == null) return Stream.value(const []);
  return ref.watch(resumeRepositoryProvider).watchResumes(uid);
});

/// Manages the "My Resumes" list — add/rename/delete/switch-active — plus
/// the skill/experience extraction that runs against whichever resume is
/// currently active. Every write here is a thin wrapper around
/// `ResumeRepository`; the interesting logic (mirroring the active
/// resume's base64 onto the profile doc so the existing AI endpoints
/// don't need a resumeId parameter) lives there — see its doc comments.
class ResumeController extends AsyncNotifier<void> {
  @override
  FutureOr<void> build() {}

  /// Adds a new named resume and immediately makes it active — matches
  /// the mental model of "upload a resume" from before multi-resume
  /// support existed: the one you just added is the one that's now in
  /// effect, not just sitting in a list doing nothing.
  Future<List<String>> addResume({required String name, required Uint8List bytes}) async {
    final uid = ref.read(currentUidProvider);
    if (uid == null) return const [];
    state = const AsyncLoading();

    var addedSkills = const <String>[];
    state = await AsyncValue.guard(() async {
      final repo = ref.read(resumeRepositoryProvider);
      final base64 = base64Encode(bytes);
      final id = await repo.addResume(uid: uid, name: name, base64: base64);
      await repo.setActive(uid: uid, resumeId: id);
      addedSkills = await _extractAndMergeSkills(uid);
    });
    return addedSkills;
  }

  /// Switches which resume is active (see `ResumeRepository.setActive`)
  /// and re-runs extraction against it — so match scoring/tailoring and
  /// the profile's skills/experience always reflect whichever resume the
  /// user just chose, not a stale one from before the switch.
  Future<List<String>> setActiveResume(String resumeId) async {
    final uid = ref.read(currentUidProvider);
    if (uid == null) return const [];
    state = const AsyncLoading();

    var addedSkills = const <String>[];
    state = await AsyncValue.guard(() async {
      await ref.read(resumeRepositoryProvider).setActive(uid: uid, resumeId: resumeId);
      addedSkills = await _extractAndMergeSkills(uid, rethrowOnError: true);
    });
    return addedSkills;
  }

  Future<void> renameResume(String resumeId, String name) async {
    final uid = ref.read(currentUidProvider);
    if (uid == null) return;
    state = const AsyncLoading();
    state = await AsyncValue.guard(() {
      return ref.read(resumeRepositoryProvider).rename(uid: uid, resumeId: resumeId, name: name);
    });
  }

  /// [wasActive] tells this whether to also clear the profile's mirrored
  /// `resumeBase64` — deleting a resume that wasn't active leaves the
  /// currently-active one (and the profile mirror) untouched.
  Future<void> deleteResume(String resumeId, {required bool wasActive}) async {
    final uid = ref.read(currentUidProvider);
    if (uid == null) return;
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      await ref.read(resumeRepositoryProvider).delete(uid: uid, resumeId: resumeId);
      if (wasActive) {
        await ref.read(profileRepositoryProvider).setResumeBase64(uid, null);
      }
    });
  }

  /// One-time backfill for a resume uploaded before multi-resume support
  /// existed: the profile doc already has `resumeBase64` set, but there's
  /// no corresponding entry in `users/{uid}/resumes/*` yet, so it would
  /// otherwise be invisible in the new "My Resumes" list. Called from
  /// `ResumeScreen` only when it observes that exact state (see there).
  Future<void> migrateLegacyResume(String base64) async {
    final uid = ref.read(currentUidProvider);
    if (uid == null) return;
    final repo = ref.read(resumeRepositoryProvider);
    final id = await repo.addResume(uid: uid, name: 'My Resume', base64: base64);
    await repo.setActive(uid: uid, resumeId: id);
  }

  /// A failed extraction (rate limit, a transient Gemini error) doesn't
  /// undo the upload/switch that already succeeded — the resume is saved
  /// either way; auto-filled skills/experience are a bonus on top, not a
  /// dependency of the upload itself, so failures here are swallowed
  /// rather than surfaced as an error. [rethrowOnError] flips that for
  /// the standalone "sync again" action below, where a failure IS the
  /// whole point of the call and needs to reach the user, not be
  /// silently absorbed.
  Future<List<String>> _extractAndMergeSkills(String uid, {bool rethrowOnError = false}) async {
    try {
      final currentSkills = ref.read(currentProfileProvider).valueOrNull?.skills ?? const [];
      final extracted = await WorkerApiService().extractResumeSkills(existingSkills: currentSkills);
      // Work experience always gets set (even to an empty list) — the
      // active resume is authoritative for this field, so one with no
      // parseable work history correctly clears any stale experience
      // from a previously-active resume rather than leaving it dangling.
      await ref.read(profileRepositoryProvider).setWorkExperience(uid, extracted.experience);
      if (extracted.skills.isEmpty) return const [];
      return await ref.read(profileRepositoryProvider).addSkills(uid, extracted.skills);
    } catch (e) {
      if (rethrowOnError) rethrow;
      return const [];
    }
  }

  /// Manual re-run of the same extraction that adding/activating a resume
  /// does automatically — for a resume that predates auto-sync, or after
  /// editing skills and wanting the active resume's list folded back in.
  /// Unlike the automatic path, failures here surface as a real error
  /// (see [_extractAndMergeSkills]).
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
}

final resumeControllerProvider = AsyncNotifierProvider<ResumeController, void>(ResumeController.new);
