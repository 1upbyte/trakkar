import 'package:flutter_map_vector_tiles/flutter_map_vector_tiles.dart' as vt;

import '../../models/map_appearance_preference.dart';

class MapLayerConfig {
  const MapLayerConfig({required this.mapTilerKey, required this.preference});

  final String? mapTilerKey;
  final MapAppearancePreference preference;

  bool get satelliteAvailable => mapTilerKey?.isNotEmpty == true;
  bool useSatellite(double zoom) =>
      satelliteAvailable && zoom >= preference.satelliteThresholdZoom;

  static String canonicalCacheIdentity(String template) {
    final uri = Uri.tryParse(template);
    if (uri == null || uri.host != 'api.maptiler.com') return template;
    final query = Map<String, String>.from(uri.queryParameters)..remove('key');
    return uri
        .replace(queryParameters: query.isEmpty ? null : query)
        .toString()
        .replaceAll('%7B', '{')
        .replaceAll('%7D', '}');
  }
}

class StableTileCacheIdentity implements vt.VectorTileProvider {
  StableTileCacheIdentity(this._delegate);

  final vt.VectorTileProvider _delegate;

  @override
  int get maximumZoom => _delegate.maximumZoom;
  @override
  int get minimumZoom => _delegate.minimumZoom;
  @override
  bool get cacheBytesToDisk => _delegate.cacheBytesToDisk;
  @override
  String get cacheKey =>
      MapLayerConfig.canonicalCacheIdentity(_delegate.cacheKey);
  @override
  Future<vt.TileResponse> load(
    vt.TileKey tile, {
    vt.CancellationToken? cancellation,
  }) => _delegate.load(tile, cancellation: cancellation);
  @override
  void dispose() => _delegate.dispose();
}

class MapTileCachePolicy {
  const MapTileCachePolicy._();

  static const freshness = Duration(days: 90);
  static const maximumSizeBytes = 512 * 1024 * 1024;
}
