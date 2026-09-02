enum MapStyleOption {
  googleStandard,
  googleSatellite,
  googleHybrid,
  googleTerrain,
  positron,
  bright,
  liberty,
  dark,
  fiord,
  satellite,
}

/// Which rendering stack draws the base map.
enum MapProvider { googleMaps, openFreeMap, mapTiler }

extension MapStyleOptionDetails on MapStyleOption {
  String get label => switch (this) {
    MapStyleOption.googleStandard => 'Google Maps – Standard',
    MapStyleOption.googleSatellite => 'Google Maps – Satellite',
    MapStyleOption.googleHybrid => 'Google Maps – Hybrid',
    MapStyleOption.googleTerrain => 'Google Maps – Terrain',
    MapStyleOption.positron => 'Minimal (OpenFreeMap Positron)',
    MapStyleOption.bright => 'Bright (OpenFreeMap)',
    MapStyleOption.liberty => 'Streets (OpenFreeMap Liberty)',
    MapStyleOption.dark => 'Dark (OpenFreeMap)',
    MapStyleOption.fiord => 'Fiord (OpenFreeMap)',
    MapStyleOption.satellite => 'Satellite (MapTiler)',
  };

  MapProvider get provider => switch (this) {
    MapStyleOption.googleStandard ||
    MapStyleOption.googleSatellite ||
    MapStyleOption.googleHybrid ||
    MapStyleOption.googleTerrain => MapProvider.googleMaps,
    MapStyleOption.satellite => MapProvider.mapTiler,
    _ => MapProvider.openFreeMap,
  };

  bool get isGoogle => provider == MapProvider.googleMaps;

  /// True for the MapTiler raster satellite style.
  bool get isSatellite => this == MapStyleOption.satellite;

  /// True when the style already shows imagery at every zoom level, so the
  /// zoom-dependent satellite switch has nothing to add.
  bool get alwaysImagery =>
      this == MapStyleOption.satellite ||
      this == MapStyleOption.googleSatellite ||
      this == MapStyleOption.googleHybrid;

  String? get openFreeMapStyleUri => provider == MapProvider.openFreeMap
      ? 'https://tiles.openfreemap.org/styles/$name'
      : null;
}
