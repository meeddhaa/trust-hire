import 'package:equatable/equatable.dart';
import '../../core/utils/firestore_codec.dart';

/// Where the user says they are in the process for one listing — not
/// derived from anything automatic (no email scanning, no bdapps
/// integration for this), just a status the user sets themselves. Order
/// matters for display (roughly the order a real application progresses).
enum ApplicationStatus {
  interested,
  applied,
  interviewing,
  offer,
  rejected;

  static ApplicationStatus fromString(String value) => ApplicationStatus.values.firstWhere(
        (v) => v.name == value,
        orElse: () => ApplicationStatus.interested,
      );
}

/// One listing the user is tracking their application progress on.
/// Client-writable (owner-only, see `firestore.rules`) — this is the
/// user's own tracking, not a verified record of anything.
class Application extends Equatable {
  const Application({
    required this.id,
    required this.userId,
    required this.listingId,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
    this.notes,
  });

  /// `'${userId}_${listingId}'` — one application record per (user,
  /// listing), same deterministic-id pattern as `MatchResult`.
  final String id;

  final String userId;
  final String listingId;
  final ApplicationStatus status;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? notes;

  static String buildId({required String userId, required String listingId}) => '${userId}_$listingId';

  factory Application.fromMap(Map<String, dynamic> map, {required String id}) {
    return Application(
      id: id,
      userId: map['userId'] as String? ?? '',
      listingId: map['listingId'] as String? ?? '',
      status: ApplicationStatus.fromString(map['status'] as String? ?? ''),
      createdAt: dateTimeFromValue(map['createdAt']),
      updatedAt: dateTimeFromValue(map['updatedAt']),
      notes: map['notes'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'listingId': listingId,
      'status': status.name,
      'createdAt': timestampFromDateTime(createdAt),
      'updatedAt': timestampFromDateTime(updatedAt),
      'notes': notes,
    };
  }

  @override
  List<Object?> get props => [id, userId, listingId, status, createdAt, updatedAt, notes];
}
