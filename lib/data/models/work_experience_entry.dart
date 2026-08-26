import 'package:equatable/equatable.dart';

/// One job/internship pulled from a resume upload — title, company, and a
/// free-text duration exactly as the resume states it (e.g. "Jan 2022 –
/// Present"), not structured start/end dates: resumes format dates too
/// inconsistently to reliably parse, and a free-text label is all the
/// profile screen displays anyway. Extracted by the same Gemini call that
/// pulls skills (see `worker/src/prompts.ts`'s `RESUME_SKILLS_RESPONSE_SCHEMA`),
/// stored as a plain list of maps on the profile doc — no separate
/// collection, since it's small and always read/written as a whole list.
class WorkExperienceEntry extends Equatable {
  const WorkExperienceEntry({required this.title, required this.company, required this.duration});

  final String title;
  final String company;
  final String duration;

  factory WorkExperienceEntry.fromMap(Map<String, dynamic> map) {
    return WorkExperienceEntry(
      title: map['title'] as String? ?? '',
      company: map['company'] as String? ?? '',
      duration: map['duration'] as String? ?? '',
    );
  }

  Map<String, dynamic> toMap() => {'title': title, 'company': company, 'duration': duration};

  @override
  List<Object?> get props => [title, company, duration];
}
