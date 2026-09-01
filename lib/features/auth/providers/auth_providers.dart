import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers/repository_providers.dart';

/// Live Firebase Auth state — `null` means signed out. The router's
/// redirect guards key off this (see `core/router/app_router.dart`).
final authStateProvider = StreamProvider<User?>((ref) {
  return ref.watch(firebaseAuthServiceProvider).authStateChanges();
});

/// Just sign-out now — signing in is the phone+OTP flow itself
/// (`SignInScreen`/`OtpVerificationScreen`, calling `WorkerApiService` and
/// `FirebaseAuthService.signInWithCustomToken` directly), not something
/// this controller drives. `AsyncNotifier<void>` so the settings/drawer
/// sign-out button can show a loading state the same way every other
/// async action in this app does.
class AuthController extends AsyncNotifier<void> {
  @override
  FutureOr<void> build() {}

  Future<void> signOut() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() => ref.read(firebaseAuthServiceProvider).signOut());
  }
}

final authControllerProvider = AsyncNotifierProvider<AuthController, void>(AuthController.new);
