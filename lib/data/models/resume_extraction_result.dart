import 'work_experience_entry.dart';

/// What `/v1/resume-skills` returns after a resume upload — both the new
/// skills to merge into the profile (see `ProfileRepository.addSkills`)
/// and the work-history list to replace it with (see
/// `ProfileRepository.setWorkExperience`). Bundled into one result because
/// it's one Gemini call reading one PDF, not two separate ones.
class ResumeExtractionResult {
  const ResumeExtractionResult({required this.skills, required this.experience});

  final List<String> skills;
  final List<WorkExperienceEntry> experience;

  factory ResumeExtractionResult.fromJson(Map<String, dynamic> json) {
    return ResumeExtractionResult(
      skills: List<String>.from(json['skills'] as List? ?? const []),
      experience: (json['experience'] as List? ?? const [])
          .map((entry) => WorkExperienceEntry.fromMap(Map<String, dynamic>.from(entry as Map)))
          .toList(),
    );
  }
}
