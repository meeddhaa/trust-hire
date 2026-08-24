import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers/repository_providers.dart';

/// Live Firebase Auth state — `null` means signed out. The router's
/// redirect guards key off this (see `core/router/app_router.dart`).
final authStateProvider = StreamProvider<User?>((ref) {
  return ref.watch(firebaseAuthServiceProvider).authStateChanges();
});

/// Drives the sign-in screen's three actions. `AsyncNotifier<void>` rather
/// than three separate booleans: `state` is `AsyncLoading` while a call is
/// in flight and `AsyncError` if it failed, which the screen reads
/// directly instead of tracking its own `isLoading`/`errorMessage` fields.
class AuthController extends AsyncNotifier<void> {
  @override
  FutureOr<void> build() {}

  Future<void> signInWithEmail({required String email, required String password}) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final authService = ref.read(firebaseAuthServiceProvider);
      final user = await authService.signInWithEmail(email: email, password: password);
      await ref.read(profileRepositoryProvider).ensureProfileExists(user);
    });
  }

  Future<void> signUpWithEmail({required String email, required String password}) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final authService = ref.read(firebaseAuthServiceProvider);
      final user = await authService.signUpWithEmail(email: email, password: password);
      await ref.read(profileRepositoryProvider).ensureProfileExists(user);
    });
  }

  /// No-ops (state stays as it was) if the user cancels the Google picker
  /// — see `FirebaseAuthService.signInWithGoogle`.
  Future<void> signInWithGoogle() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final authService = ref.read(firebaseAuthServiceProvider);
      final user = await authService.signInWithGoogle();
      if (user == null) return;
      await ref.read(profileRepositoryProvider).ensureProfileExists(user);
    });
  }

  Future<void> signOut() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() => ref.read(firebaseAuthServiceProvider).signOut());
  }
}

final authControllerProvider = AsyncNotifierProvider<AuthController, void>(AuthController.new);
