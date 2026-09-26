import 'package:shared_preferences/shared_preferences.dart';

import '../../models/map_appearance_preference.dart';
import '../../models/theme_preference.dart';

class PreferencesRepository {
  // Keep the injectable preference store optional and its field private.
  PreferencesRepository({SharedPreferences? preferences})
    // ignore: prefer_initializing_formals
    : _preferences = preferences;

  static const _themeKey = 'settings.themeMode';
  static const _thresholdKey = 'map.satelliteThresholdZoom';
  final SharedPreferences? _preferences;

  Future<SharedPreferences> get _store async =>
      _preferences ?? await SharedPreferences.getInstance();

  Future<AppThemePreference> readTheme() async =>
      AppThemePreferenceCodec.parse((await _store).getString(_themeKey));

  Future<void> saveTheme(AppThemePreference preference) async {
    await (await _store).setString(_themeKey, preference.storageValue);
  }

  Future<MapAppearancePreference> readMapAppearance() async {
    final prefs = await _store;
    return MapAppearancePreference(
      satelliteThresholdZoom: prefs.getDouble(_thresholdKey) ?? 19,
    );
  }

  Future<void> saveMapAppearance(MapAppearancePreference preference) async {
    await (await _store).setDouble(
      _thresholdKey,
      preference.satelliteThresholdZoom,
    );
  }

  Future<void> reset() async {
    final prefs = await _store;
    await prefs.remove(_themeKey);
    await prefs.setDouble(_thresholdKey, 19);
  }
}
