import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers/repository_providers.dart';
import '../../../core/providers/session_providers.dart';

/// Base64-encodes the picked PDF and writes it straight to the profile
/// doc via `ProfileRepository` — no separate upload/delete calls to a
/// file store, since there isn't one (see "Decision: resume storage,
/// twice reconsidered" in docs/ARCHITECTURE.md).
class ResumeController extends AsyncNotifier<void> {
  @override
  FutureOr<void> build() {}

  Future<void> uploadResume(Uint8List bytes) async {
    final uid = ref.read(currentUidProvider);
    if (uid == null) return;
    state = const AsyncLoading();
    state = await AsyncValue.guard(() {
      return ref.read(profileRepositoryProvider).setResumeBase64(uid, base64Encode(bytes));
    });
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
