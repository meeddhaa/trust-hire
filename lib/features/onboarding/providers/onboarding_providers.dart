import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/errors/failure.dart';
import '../../../core/providers/repository_providers.dart';
import '../../../core/providers/session_providers.dart';

/// Saves the onboarding form. A thin wrapper over `ProfileRepository` —
/// its only job is turning the screen's plain field values into the
/// `AsyncLoading`/`AsyncError`/`AsyncData` states the screen renders.
class OnboardingController extends AsyncNotifier<void> {
  @override
  FutureOr<void> build() {}

  Future<void> submit({
    required List<String> skills,
    int? yearsOfExperience,
    String? educationLevel,
    String? headline,
  }) async {
    final uid = ref.read(currentUidProvider);
    if (uid == null) {
      state = AsyncError(const AuthFailure('Please sign in again.'), StackTrace.current);
      return;
    }
    state = const AsyncLoading();
    state = await AsyncValue.guard(() {
      return ref.read(profileRepositoryProvider).saveOnboarding(
            uid: uid,
            skills: skills,
            yearsOfExperience: yearsOfExperience,
            educationLevel: educationLevel,
            headline: headline,
          );
    });
  }
}

final onboardingControllerProvider = AsyncNotifierProvider<OnboardingController, void>(
  OnboardingController.new,
);
