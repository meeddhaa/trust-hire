import 'package:equatable/equatable.dart';

import '../../core/utils/firestore_codec.dart';

enum SubscriptionTier { free, paid }

enum SubscriptionStatus {
  /// No bdapps subscription has ever been created for this user — the
  /// default before any paywall interaction, distinct from `canceled`.
  none,
  active,
  canceled,
  expired;

  static SubscriptionStatus fromString(String value) => SubscriptionStatus.values.firstWhere(
        (v) => v.name == value,
        orElse: () => SubscriptionStatus.none,
      );
}

/// A user's bdapps DCB subscription state, stored at
/// `subscriptions/{uid}`. Written only by the server-side bdapps webhook
/// handler (see `firestore.rules`) — the client reads this to decide which
/// tier of `MatchResult`/`ScamAssessment` fields to render, and to drive
/// the paywall and unsubscribe screens, but never sets it directly. That
/// keeps a modified client from granting itself the paid tier for free.
class Subscription extends Equatable {
  const Subscription({
    required this.uid,
    this.tier = SubscriptionTier.free,
    this.status = SubscriptionStatus.none,
    this.bdappsSubscriptionId,
    this.startedAt,
    this.renewsAt,
    this.canceledAt,
  });

  final String uid;
  final SubscriptionTier tier;
  final SubscriptionStatus status;

  /// bdapps' own subscription identifier, needed to call their unsubscribe
  /// endpoint. Null until the user has subscribed at least once.
  final String? bdappsSubscriptionId;

  final DateTime? startedAt;

  /// Next DCB billing date. Null once canceled.
  final DateTime? renewsAt;
  final DateTime? canceledAt;

  /// The single source of truth the whole app gates paid features on —
  /// `tier == paid` alone isn't enough if a cancellation hasn't taken
  /// effect until period end, so this also checks `status`.
  bool get isPaid => tier == SubscriptionTier.paid && status == SubscriptionStatus.active;

  /// Default shape for a user who has never subscribed — used wherever a
  /// `subscriptions/{uid}` doc doesn't exist yet, so the rest of the app
  /// can treat "no document" and "explicitly free" identically.
  factory Subscription.free(String uid) => Subscription(uid: uid);

  factory Subscription.fromMap(Map<String, dynamic> map, {required String uid}) {
    return Subscription(
      uid: uid,
      tier: SubscriptionTier.values.firstWhere(
        (v) => v.name == map['tier'],
        orElse: () => SubscriptionTier.free,
      ),
      status: SubscriptionStatus.fromString(map['status'] as String? ?? ''),
      bdappsSubscriptionId: map['bdappsSubscriptionId'] as String?,
      startedAt: dateTimeFromValueOrNull(map['startedAt']),
      renewsAt: dateTimeFromValueOrNull(map['renewsAt']),
      canceledAt: dateTimeFromValueOrNull(map['canceledAt']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'tier': tier.name,
      'status': status.name,
      'bdappsSubscriptionId': bdappsSubscriptionId,
      'startedAt': startedAt == null ? null : timestampFromDateTime(startedAt!),
      'renewsAt': renewsAt == null ? null : timestampFromDateTime(renewsAt!),
      'canceledAt': canceledAt == null ? null : timestampFromDateTime(canceledAt!),
    };
  }

  @override
  List<Object?> get props => [
        uid,
        tier,
        status,
        bdappsSubscriptionId,
        startedAt,
        renewsAt,
        canceledAt,
      ];
}
