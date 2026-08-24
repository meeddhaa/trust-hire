import 'package:cloud_firestore/cloud_firestore.dart';
import '../../core/constants/firestore_collections.dart';
import '../../core/constants/worker_config.dart';
import '../models/match_result.dart';
import '../services/worker_api_service.dart';

/// Explainable match results, cached per `(user, listing)`.
///
/// Reads `matchResults/{uid}_{listingId}` directly first — a plain
/// Firestore read the client is already allowed (own results only, per
/// `firestore.rules`) — and only calls the Worker (slower: token
/// verification, its own Firestore round trip, possibly a Gemini call) on
/// a cache miss or stale `modelVersion`. See `docs/ARCHITECTURE.md` →
/// "Data flow: match + scam assessment".
class MatchRepository {
  MatchRepository({FirebaseFirestore? firestore, WorkerApiService? workerApi})
      : _firestore = firestore ?? FirebaseFirestore.instance,
        _workerApi = workerApi ?? WorkerApiService();

  final FirebaseFirestore _firestore;
  final WorkerApiService _workerApi;

  Future<MatchResult> getMatch({required String uid, required String listingId}) async {
    final matchId = MatchResult.buildId(userId: uid, listingId: listingId);
    final cached = await _tryReadCache(matchId);
    if (cached != null) return cached;

    // No usable cache — the Worker owns the source of truth here and will
    // re-check its own cache before spending a Gemini call, so this is
    // also where the actual write happens on a true miss.
    return _workerApi.fetchMatch(listingId);
  }

  /// A cache-read failure (offline, permission hiccup) isn't fatal on its
  /// own — it just means we fall through to the Worker call, which has its
  /// own robust error handling. Returns `null` for "no cache", not just
  /// "no data" — a stale `modelVersion` also counts as no usable cache.
  Future<MatchResult?> _tryReadCache(String matchId) async {
    try {
      final snapshot =
          await _firestore.collection(FirestoreCollections.matchResults).doc(matchId).get();
      final data = snapshot.data();
      if (data == null || data['modelVersion'] != WorkerConfig.matchModelVersion) return null;
      return MatchResult.fromMap(data, id: matchId);
    } catch (_) {
      return null;
    }
  }
}
