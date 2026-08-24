import 'package:cloud_firestore/cloud_firestore.dart';
import '../../core/constants/firestore_collections.dart';
import '../models/subscription.dart';

/// Reads `subscriptions/{uid}` — written only by the bdapps webhook
/// handler (step 7), never the client (see `firestore.rules`). Until
/// step 7 lands, every user reads as free tier by default, which is the
/// correct behavior for "no document exists yet" too — see
/// `Subscription.free`.
class SubscriptionRepository {
  SubscriptionRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  Stream<Subscription> watchSubscription(String uid) {
    return _firestore.collection(FirestoreCollections.subscriptions).doc(uid).snapshots().map((
      snapshot,
    ) {
      final data = snapshot.data();
      if (data == null) return Subscription.free(uid);
      return Subscription.fromMap(data, uid: uid);
    });
  }
}
