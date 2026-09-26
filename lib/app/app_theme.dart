import 'package:flutter/material.dart';

import '../models/theme_preference.dart';
import '../services/settings/preferences_repository.dart';

class AppThemeController extends ChangeNotifier {
  // Keep a public injection name while the dependency field remains private.
  AppThemeController({required PreferencesRepository preferences})
    // ignore: prefer_initializing_formals
    : _preferences = preferences;

  final PreferencesRepository _preferences;
  AppThemePreference preference = AppThemePreference.system;

  ThemeMode get themeMode => switch (preference) {
    AppThemePreference.system => ThemeMode.system,
    AppThemePreference.light => ThemeMode.light,
    AppThemePreference.dark => ThemeMode.dark,
  };

  Future<void> load() async {
    preference = await _preferences.readTheme();
    notifyListeners();
  }

  Future<void> select(AppThemePreference value) async {
    final previous = preference;
    preference = value;
    notifyListeners();
    try {
      await _preferences.saveTheme(value);
    } on Object {
      preference = previous;
      notifyListeners();
      rethrow;
    }
  }

  Future<void> reset() async {
    await _preferences.reset();
    preference = AppThemePreference.system;
    notifyListeners();
  }
}
