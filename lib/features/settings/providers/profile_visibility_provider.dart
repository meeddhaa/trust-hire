import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _prefsKey = 'profile_visibility';

/// A stored preference with nothing behind it yet — no employer-facing
/// view of any profile exists in the app today, so there's nothing to
/// actually enforce "public" vs. "private" against. Built anyway (per an
/// explicit ask) so the choice is captured and ready the moment a viewing
/// feature exists, rather than needing this UI built from scratch later.
/// The Settings screen's copy says this plainly instead of implying it
/// already controls something.
enum ProfileVisibility { public, private }

class ProfileVisibilityNotifier extends Notifier<ProfileVisibility> {
  @override
  ProfileVisibility build() {
    _loadPersisted();
    return ProfileVisibility.private;
  }

  Future<void> _loadPersisted() async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getString(_prefsKey);
    final value = ProfileVisibility.values.firstWhere(
      (v) => v.name == stored,
      orElse: () => ProfileVisibility.private,
    );
    if (value != state) state = value;
  }

  Future<void> setVisibility(ProfileVisibility value) async {
    state = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsKey, value.name);
  }
}

final profileVisibilityProvider =
    NotifierProvider<ProfileVisibilityNotifier, ProfileVisibility>(ProfileVisibilityNotifier.new);
