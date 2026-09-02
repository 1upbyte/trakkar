import 'package:flutter_test/flutter_test.dart';
import 'package:trakkar/models/map_style_option.dart';

void main() {
  test('google styles use the Google Maps SDK and no OpenFreeMap style', () {
    for (final style in MapStyleOption.values.where((s) => s.isGoogle)) {
      expect(style.provider, MapProvider.googleMaps);
      expect(style.openFreeMapStyleUri, isNull);
    }
  });

  test('OpenFreeMap styles keep their vector style URIs', () {
    expect(
      MapStyleOption.positron.openFreeMapStyleUri,
      'https://tiles.openfreemap.org/styles/positron',
    );
    expect(MapStyleOption.satellite.openFreeMapStyleUri, isNull);
    expect(MapStyleOption.satellite.provider, MapProvider.mapTiler);
  });

  test('imagery-only styles disable the zoom-based satellite switch', () {
    expect(MapStyleOption.googleSatellite.alwaysImagery, isTrue);
    expect(MapStyleOption.googleHybrid.alwaysImagery, isTrue);
    expect(MapStyleOption.satellite.alwaysImagery, isTrue);
    expect(MapStyleOption.googleStandard.alwaysImagery, isFalse);
    expect(MapStyleOption.googleTerrain.alwaysImagery, isFalse);
    expect(MapStyleOption.positron.alwaysImagery, isFalse);
  });
}
