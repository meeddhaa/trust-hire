import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/repositories/application_repository.dart';
import '../../data/repositories/listings_repository.dart';
import '../../data/repositories/match_repository.dart';
import '../../data/repositories/profile_repository.dart';
import '../../data/repositories/saved_job_repository.dart';
import '../../data/repositories/scam_repository.dart';
import '../../data/repositories/subscription_repository.dart';
import '../../data/services/firebase_auth_service.dart';
import '../../data/services/resume_service.dart';

/// Plain `Provider`s for repositories/services shared across three or more
/// features (listings, listing_detail, onboarding, profile, paywall,
/// subscription all touch at least one of these) — centralized here
/// instead of re-declared per feature, since they hold no per-feature
/// state, just DI. Feature-specific state (form controllers, per-listing
/// async results) stays in each feature's own `providers/` folder.
final firebaseAuthServiceProvider = Provider<FirebaseAuthService>((ref) => FirebaseAuthService());

final profileRepositoryProvider = Provider<ProfileRepository>((ref) => ProfileRepository());

final listingsRepositoryProvider = Provider<ListingsRepository>((ref) => ListingsRepository());

final matchRepositoryProvider = Provider<MatchRepository>((ref) => MatchRepository());

final scamRepositoryProvider = Provider<ScamRepository>((ref) => ScamRepository());

final subscriptionRepositoryProvider = Provider<SubscriptionRepository>(
  (ref) => SubscriptionRepository(),
);

final resumeServiceProvider = Provider<ResumeService>((ref) => ResumeService());

final applicationRepositoryProvider = Provider<ApplicationRepository>((ref) => ApplicationRepository());

final savedJobRepositoryProvider = Provider<SavedJobRepository>((ref) => SavedJobRepository());
