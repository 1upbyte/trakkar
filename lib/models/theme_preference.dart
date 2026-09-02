enum ThemePreference { system, light, dark }

extension ThemePreferenceDetails on ThemePreference {
  String get label => switch (this) {
    ThemePreference.system => 'System',
    ThemePreference.light => 'Light',
    ThemePreference.dark => 'Dark',
  };
}
