import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/models/resume_tailor_result.dart';
import '../../../data/services/worker_api_service.dart';

/// On-demand, not eager like `matchResultProvider`/`scamAssessmentProvider`
/// — resume tailoring is an optional action the user triggers with a
/// button (it needs an uploaded resume and is a heavier Gemini call), not
/// something to fire automatically for every listing detail view.
class ResumeTailorController extends AsyncNotifier<ResumeTailorResult?> {
  @override
  FutureOr<ResumeTailorResult?> build() => null;

  Future<void> tailorFor(String listingId) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() => WorkerApiService().fetchResumeTailoring(listingId));
  }
}

final resumeTailorControllerProvider =
    AsyncNotifierProvider<ResumeTailorController, ResumeTailorResult?>(ResumeTailorController.new);
