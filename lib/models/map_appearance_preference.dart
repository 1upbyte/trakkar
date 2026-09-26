class MapAppearancePreference {
  const MapAppearancePreference({this.satelliteThresholdZoom = 19});

  final double satelliteThresholdZoom;

  MapAppearancePreference copyWith({double? satelliteThresholdZoom}) =>
      MapAppearancePreference(
        satelliteThresholdZoom:
            satelliteThresholdZoom ?? this.satelliteThresholdZoom,
      );
}
