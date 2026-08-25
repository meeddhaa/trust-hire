import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _prefsKey = 'theme_mode';

/// User's chosen appearance (light/dark/system), persisted locally —
/// non-sensitive UI state, so `shared_preferences` (already a dependency)
/// is the right fit, not Firestore. Read once at startup; `setThemeMode`
/// updates both the in-memory state and the persisted value.
class ThemeModeNotifier extends Notifier<ThemeMode> {
  @override
  ThemeMode build() {
    _loadPersisted();
    return ThemeMode.system;
  }

  Future<void> _loadPersisted() async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getString(_prefsKey);
    final mode = ThemeMode.values.firstWhere(
      (m) => m.name == stored,
      orElse: () => ThemeMode.system,
    );
    if (mode != state) state = mode;
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    state = mode;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsKey, mode.name);
  }
}

final themeModeProvider = NotifierProvider<ThemeModeNotifier, ThemeMode>(ThemeModeNotifier.new);
