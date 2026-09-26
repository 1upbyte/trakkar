enum AppThemePreference { system, light, dark }

extension AppThemePreferenceCodec on AppThemePreference {
  String get storageValue => name;

  static AppThemePreference parse(String? value) =>
      AppThemePreference.values
          .where((mode) => mode.name == value)
          .firstOrNull ??
      AppThemePreference.system;
}
