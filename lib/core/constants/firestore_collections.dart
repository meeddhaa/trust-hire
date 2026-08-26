/// Firestore collection names, in one place so a typo doesn't silently
/// create a sibling collection. Must stay in sync with the `match` paths in
/// `firestore.rules` at the repo root.
abstract final class FirestoreCollections {
  static const users = 'users';
  static const listings = 'listings';
  static const matchResults = 'matchResults';
  static const scamAssessments = 'scamAssessments';
  static const subscriptions = 'subscriptions';
  static const applications = 'applications';
  static const savedJobs = 'savedJobs';

  /// Subcollection under `users/{uid}` — see `Resume` model.
  static const resumes = 'resumes';
}
