import 'package:shared_preferences/shared_preferences.dart';

import '../../models/map_appearance_preference.dart';

class MapPreferences {
  MapPreferences({this._preferences});

  static const _thresholdKey = 'map.satelliteThresholdZoom';
  final SharedPreferences? _preferences;

  Future<MapAppearancePreference> read() async {
    final preferences = _preferences ?? await SharedPreferences.getInstance();
    return MapAppearancePreference(
      satelliteThresholdZoom: preferences.getDouble(_thresholdKey) ?? 19,
    );
  }

  Future<void> save(MapAppearancePreference preference) async {
    final preferences = _preferences ?? await SharedPreferences.getInstance();
    await preferences.setDouble(
      _thresholdKey,
      preference.satelliteThresholdZoom,
    );
  }
}
