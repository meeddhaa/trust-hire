import 'package:cloud_firestore/cloud_firestore.dart';
import '../../core/constants/firestore_collections.dart';
import '../../core/constants/worker_config.dart';
import '../models/scam_assessment.dart';
import '../services/worker_api_service.dart';

/// Scam-risk assessments, cached per listing (not per user — see
/// `ScamAssessment`'s doc comment). Same cache-then-Worker pattern as
/// `MatchRepository`.
class ScamRepository {
  ScamRepository({FirebaseFirestore? firestore, WorkerApiService? workerApi})
      : _firestore = firestore ?? FirebaseFirestore.instance,
        _workerApi = workerApi ?? WorkerApiService();

  final FirebaseFirestore _firestore;
  final WorkerApiService _workerApi;

  Future<ScamAssessment> getAssessment(String listingId) async {
    final cached = await _tryReadCache(listingId);
    if (cached != null) return cached;
    return _workerApi.fetchScamAssessment(listingId);
  }

  Future<ScamAssessment?> _tryReadCache(String listingId) async {
    try {
      final snapshot =
          await _firestore.collection(FirestoreCollections.scamAssessments).doc(listingId).get();
      final data = snapshot.data();
      if (data == null || data['modelVersion'] != WorkerConfig.scamModelVersion) return null;
      return ScamAssessment.fromMap(data, listingId: listingId);
    } catch (_) {
      return null;
    }
  }
}
