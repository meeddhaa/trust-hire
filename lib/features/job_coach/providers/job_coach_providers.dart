import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/models/job_coach_result.dart';
import '../../../data/services/worker_api_service.dart';

/// On-demand, same pattern as `ResumeTailorController` — Job Coach is a
/// single-shot request per question/intent (see `worker/src/index.ts`'s
/// `handleJobCoach` doc comment for why there's no persisted multi-turn
/// memory in this pass), not a live streaming chat.
class JobCoachController extends AsyncNotifier<JobCoachResult?> {
  @override
  FutureOr<JobCoachResult?> build() => null;

  Future<void> ask({required String intent, String? listingId, String? question}) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => WorkerApiService().askJobCoach(intent: intent, listingId: listingId, question: question),
    );
  }

  void reset() => state = const AsyncData(null);
}

final jobCoachControllerProvider =
    AsyncNotifierProvider<JobCoachController, JobCoachResult?>(JobCoachController.new);
