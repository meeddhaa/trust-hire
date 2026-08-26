import 'package:equatable/equatable.dart';

/// One Job Coach response — not persisted (see `worker/src/index.ts`'s
/// `handleJobCoach`; same reasoning as `ResumeTailorResult`: always fresh,
/// no multi-turn memory kept server-side).
class JobCoachResult extends Equatable {
  const JobCoachResult({required this.answer, required this.followUpSuggestions});

  final String answer;
  final List<String> followUpSuggestions;

  factory JobCoachResult.fromJson(Map<String, dynamic> json) {
    return JobCoachResult(
      answer: json['answer'] as String? ?? '',
      followUpSuggestions: List<String>.from(json['followUpSuggestions'] as List? ?? const []),
    );
  }

  @override
  List<Object?> get props => [answer, followUpSuggestions];
}
