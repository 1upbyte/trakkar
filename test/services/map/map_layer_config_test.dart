import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:trakkar/models/map_appearance_preference.dart';
import 'package:trakkar/services/map/map_layer_config.dart';
import 'package:trakkar/services/map/map_preferences.dart';

void main() {
  test('new users default to satellite threshold 19; threshold crossing is inclusive', () {
    const config = MapLayerConfig(
      mapTilerKey: 'server-key',
      preference: MapAppearancePreference(),
    );
    expect(config.preference.satelliteThresholdZoom, 19);
    expect(config.useSatellite(18.999), isFalse);
    expect(config.useSatellite(19), isTrue);
  });

  test('missing key keeps standard map active', () {
    const config = MapLayerConfig(
      mapTilerKey: null,
      preference: MapAppearancePreference(satelliteThresholdZoom: 16),
    );
    expect(config.satelliteAvailable, isFalse);
    expect(config.useSatellite(20), isFalse);
  });

  test(
    'MapTiler cache identity strips key and preserves other query values',
    () {
      expect(
        MapLayerConfig.canonicalCacheIdentity(
          'https://api.maptiler.com/tiles/a/{z}/{x}/{y}.pbf?key=private&tileSize=512',
        ),
        'https://api.maptiler.com/tiles/a/{z}/{x}/{y}.pbf?tileSize=512',
      );
      expect(
        MapLayerConfig.canonicalCacheIdentity(
          'https://tiles.openfreemap.org/{z}/{x}/{y}',
        ),
        'https://tiles.openfreemap.org/{z}/{x}/{y}',
      );
    },
  );

  test(
    'threshold preference persists separately from initial camera framing',
    () async {
      SharedPreferences.setMockInitialValues({});
      final preferences = MapPreferences();
      expect((await preferences.read()).satelliteThresholdZoom, 19);
      await preferences.save(
        const MapAppearancePreference(satelliteThresholdZoom: 17),
      );
      expect((await preferences.read()).satelliteThresholdZoom, 17);
    },
  );
}
