import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers/repository_providers.dart';
import '../../../core/providers/session_providers.dart';

/// Orchestrates account deletion: everything the client owns and can
/// delete (applications, saved jobs, resume file, profile doc) goes
/// first, then the Auth account itself — deleting Auth first would leave
/// an orphaned, un-authorized-to-delete trail of the user's own data.
///
/// **Known limitation, not silently swept under the rug**: `matchResults`
/// and `scamAssessments` are server-write-only (see `firestore.rules`),
/// so the client can't purge those here. They contain no directly
/// identifying data beyond a now-deleted `uid` string — low residual risk
/// — but a genuinely complete purge needs a Worker admin endpoint, which
/// is a deliberate fast-follow, not built in this pass.
class AccountController extends AsyncNotifier<void> {
  @override
  FutureOr<void> build() {}

  Future<void> deleteAccount() async {
    final uid = ref.read(currentUidProvider);
    if (uid == null) return;

    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      await ref.read(applicationRepositoryProvider).deleteAllForUser(uid);
      await ref.read(savedJobRepositoryProvider).deleteAllForUser(uid);
      try {
        await ref.read(resumeServiceProvider).deleteResume(uid);
      } catch (_) {
        // No resume to delete is fine; don't block account deletion on it.
      }
      await ref.read(profileRepositoryProvider).deleteProfile(uid);
      await ref.read(firebaseAuthServiceProvider).deleteAccount();
    });
  }
}

final accountControllerProvider = AsyncNotifierProvider<AccountController, void>(AccountController.new);
