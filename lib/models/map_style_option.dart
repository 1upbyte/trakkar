enum MapStyleOption { positron, bright, liberty, dark, fiord, satellite }

extension MapStyleOptionDetails on MapStyleOption {
  String get label => switch (this) {
    MapStyleOption.positron => 'Minimal (OpenFreeMap Positron)',
    MapStyleOption.bright => 'Bright (OpenFreeMap)',
    MapStyleOption.liberty => 'Streets (OpenFreeMap Liberty)',
    MapStyleOption.dark => 'Dark (OpenFreeMap)',
    MapStyleOption.fiord => 'Fiord (OpenFreeMap)',
    MapStyleOption.satellite => 'Satellite (MapTiler)',
  };

  bool get isSatellite => this == MapStyleOption.satellite;

  String? get openFreeMapStyleUri =>
      isSatellite ? null : 'https://tiles.openfreemap.org/styles/$name';
}
