import 'package:equatable/equatable.dart';
import '../../core/utils/firestore_codec.dart';

/// One named resume version, stored at `users/{uid}/resumes/{resumeId}` —
/// the brief's "My Resumes" (e.g. "AI/LLM Resume", "General Resume").
/// Exactly one is [isActive] at a time: that one's [base64] is mirrored
/// onto `UserProfile.resumeBase64` (see `ResumeRepository.setActive`) so
/// every existing worker endpoint (skill extraction, resume tailoring)
/// keeps reading that single field unchanged — multi-resume is a
/// management layer on top of the same single-active-resume backend, not
/// a rebuild of the AI pipeline to carry a resumeId around.
class Resume extends Equatable {
  const Resume({
    required this.id,
    required this.name,
    required this.base64,
    required this.isActive,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String name;
  final String base64;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;

  factory Resume.fromMap(Map<String, dynamic> map, {required String id}) {
    return Resume(
      id: id,
      name: map['name'] as String? ?? 'Resume',
      base64: map['base64'] as String? ?? '',
      isActive: map['isActive'] as bool? ?? false,
      createdAt: dateTimeFromValue(map['createdAt']),
      updatedAt: dateTimeFromValue(map['updatedAt']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'base64': base64,
      'isActive': isActive,
      'createdAt': timestampFromDateTime(createdAt),
      'updatedAt': timestampFromDateTime(updatedAt),
    };
  }

  Resume copyWith({String? name, String? base64, bool? isActive, DateTime? updatedAt}) {
    return Resume(
      id: id,
      name: name ?? this.name,
      base64: base64 ?? this.base64,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt,
      updatedAt: updatedAt ?? DateTime.now(),
    );
  }

  @override
  List<Object?> get props => [id, name, base64, isActive, createdAt, updatedAt];
}
