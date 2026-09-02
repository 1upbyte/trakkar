/// Map SDK keys shared through the manager account.
///
/// The keys live in the Traccar manager user's `attributes` so every phone
/// signed into the same account receives them without a modified server.
class MapApiKeys {
  const MapApiKeys({this.googleMaps = '', this.mapTiler = ''});

  factory MapApiKeys.fromAttributes(Map<String, dynamic> attributes) {
    return MapApiKeys(
      googleMaps: _clean(attributes[googleMapsAttribute]),
      mapTiler: _clean(attributes[mapTilerAttribute]),
    );
  }

  static const googleMapsAttribute = 'trakkarGoogleMapsApiKey';
  static const mapTilerAttribute = 'trakkarMapTilerApiKey';

  final String googleMaps;
  final String mapTiler;

  bool get isEmpty => googleMaps.isEmpty && mapTiler.isEmpty;

  MapApiKeys copyWith({String? googleMaps, String? mapTiler}) {
    return MapApiKeys(
      googleMaps: _clean(googleMaps ?? this.googleMaps),
      mapTiler: _clean(mapTiler ?? this.mapTiler),
    );
  }

  /// Returns a copy where empty local values are filled from [other].
  MapApiKeys mergedWith(MapApiKeys other) {
    return MapApiKeys(
      googleMaps: other.googleMaps.isNotEmpty ? other.googleMaps : googleMaps,
      mapTiler: other.mapTiler.isNotEmpty ? other.mapTiler : mapTiler,
    );
  }

  /// Merges these keys into an existing attribute map. Empty keys remove the
  /// attribute so a cleared field also clears the server.
  Map<String, dynamic> applyTo(Map<String, dynamic> attributes) {
    final updated = Map<String, dynamic>.from(attributes);
    if (googleMaps.isEmpty) {
      updated.remove(googleMapsAttribute);
    } else {
      updated[googleMapsAttribute] = googleMaps;
    }
    if (mapTiler.isEmpty) {
      updated.remove(mapTilerAttribute);
    } else {
      updated[mapTilerAttribute] = mapTiler;
    }
    return updated;
  }

  @override
  bool operator ==(Object other) =>
      other is MapApiKeys &&
      other.googleMaps == googleMaps &&
      other.mapTiler == mapTiler;

  @override
  int get hashCode => Object.hash(googleMaps, mapTiler);

  static String _clean(Object? value) => value is String ? value.trim() : '';
}
