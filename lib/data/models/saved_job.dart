import 'package:equatable/equatable.dart';
import '../../core/utils/firestore_codec.dart';

/// A bookmarked listing — client-writable, owner-only (see
/// `firestore.rules`). Deliberately minimal: just the fact of saving it
/// and when, nothing else to track.
class SavedJob extends Equatable {
  const SavedJob({required this.id, required this.userId, required this.listingId, required this.savedAt});

  /// `'${userId}_${listingId}'` — same pattern as `Application`/`MatchResult`.
  final String id;

  final String userId;
  final String listingId;
  final DateTime savedAt;

  static String buildId({required String userId, required String listingId}) => '${userId}_$listingId';

  factory SavedJob.fromMap(Map<String, dynamic> map, {required String id}) {
    return SavedJob(
      id: id,
      userId: map['userId'] as String? ?? '',
      listingId: map['listingId'] as String? ?? '',
      savedAt: dateTimeFromValue(map['savedAt']),
    );
  }

  Map<String, dynamic> toMap() {
    return {'userId': userId, 'listingId': listingId, 'savedAt': timestampFromDateTime(savedAt)};
  }

  @override
  List<Object?> get props => [id, userId, listingId, savedAt];
}
