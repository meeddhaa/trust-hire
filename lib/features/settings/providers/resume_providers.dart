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

  /// After a successful upload, also asks Gemini to extract skills from
  /// the resume and folds any genuinely new ones into the profile — so
  /// match scoring/cross-referencing against listings draws on the
  /// resume's actual content, not just whatever was typed in onboarding.
  /// Returns the skills actually added, so the caller can tell the user
  /// something concrete ("added 4 skills") instead of just "done."
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
  /// way; auto-filled skills are a bonus on top, not a dependency of the
  /// upload itself, so failures here are swallowed rather than surfaced
  /// as an upload error.
  Future<List<String>> _extractAndMergeSkills(String uid) async {
    try {
      final currentSkills = ref.read(currentProfileProvider).valueOrNull?.skills ?? const [];
      final extracted = await WorkerApiService().extractResumeSkills(existingSkills: currentSkills);
      if (extracted.isEmpty) return const [];
      return await ref.read(profileRepositoryProvider).addSkills(uid, extracted);
    } catch (_) {
      return const [];
    }
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
