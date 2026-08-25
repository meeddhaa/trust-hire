import 'dart:async';
import 'dart:typed_data';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers/repository_providers.dart';
import '../../../core/providers/session_providers.dart';

/// Uploads/deletes the resume: writes the PDF to Storage via
/// `ResumeService`, then records the path on the profile doc via
/// `ProfileRepository` — two calls, one user action, so this notifier is
/// what keeps them atomic-ish from the UI's point of view (either both
/// succeed, or the error surfaces and the profile doc is never left
/// pointing at a path that doesn't exist).
class ResumeController extends AsyncNotifier<void> {
  @override
  FutureOr<void> build() {}

  Future<void> uploadResume(Uint8List bytes) async {
    final uid = ref.read(currentUidProvider);
    if (uid == null) return;
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final path = await ref.read(resumeServiceProvider).uploadResume(uid: uid, bytes: bytes);
      await ref.read(profileRepositoryProvider).setResumeStoragePath(uid, path);
    });
  }

  Future<void> deleteResume() async {
    final uid = ref.read(currentUidProvider);
    if (uid == null) return;
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      await ref.read(resumeServiceProvider).deleteResume(uid);
      await ref.read(profileRepositoryProvider).setResumeStoragePath(uid, null);
    });
  }
}

final resumeControllerProvider = AsyncNotifierProvider<ResumeController, void>(ResumeController.new);
