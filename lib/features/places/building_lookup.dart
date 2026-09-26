import 'dart:collection';
import 'dart:io' show gzip;
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_vector_tiles/flutter_map_vector_tiles.dart' as vt;
import 'package:latlong2/latlong.dart';
import 'package:vector_tile/vector_tile.dart' as mvt;

import '../../services/places/place_geometry.dart';

class BuildingCandidate {
  const BuildingCandidate({
    required this.id,
    required this.name,
    required this.points,
  });

  final String id;
  final String name;
  final List<LatLng> points;

  bool contains(LatLng point) {
    if (points.length < 3) return false;
    var inside = false;
    for (var i = 0, j = points.length - 1; i < points.length; j = i++) {
      final a = points[i];
      final b = points[j];
      final crosses =
          (a.latitude > point.latitude) != (b.latitude > point.latitude) &&
          point.longitude <
              (b.longitude - a.longitude) *
                      (point.latitude - a.latitude) /
                      (b.latitude - a.latitude) +
                  a.longitude;
      if (crosses) inside = !inside;
    }
    return inside;
  }
}

class BuildingLookupResult {
  const BuildingLookupResult({
    this.candidates = const [],
    this.message,
    this.hadTileFailure = false,
  });

  final List<BuildingCandidate> candidates;
  final String? message;
  final bool hadTileFailure;
}

typedef BuildingTileLoader = Future<vt.TileResponse> Function(
  vt.VectorTileProvider provider,
  vt.TileKey key,
);

class BuildingLookup {
  BuildingLookup({
    required this.style,
    this.sourceId,
    this.tileLoader,
    this.maxTiles = 48,
  });

  final vt.Style style;
  final String? sourceId;
  final BuildingTileLoader? tileLoader;
  final int maxTiles;
  final LinkedHashMap<String, List<BuildingCandidate>> _tileCache =
      LinkedHashMap();

  static const minimumDisplayZoom = 16.0;
  static const sourceLayerName = 'building';

  Future<BuildingLookupResult> lookup({
    required LatLngBounds bounds,
    required double displayZoom,
  }) async {
    if (displayZoom < minimumDisplayZoom) {
      return const BuildingLookupResult(
        message: 'Zoom in to level 16 or closer to find buildings.',
      );
    }
    final source = sourceId ?? _buildingSource(style.theme);
    if (source == null) {
      return const BuildingLookupResult(
        message: 'Building outlines are unavailable in this map style.',
      );
    }
    final provider = style.providers.providers[source];
    if (provider == null) {
      return const BuildingLookupResult(
        message: 'Building outlines are unavailable in this map style.',
      );
    }

    // MapLibre's 512-pixel style convention uses the tile one level below
    // flutter_map's display zoom, matching VectorTileLayer's default offset.
    final zoom = (displayZoom.floor() - 1).clamp(
      provider.minimumZoom,
      provider.maximumZoom,
    );
    final keys = _visibleTiles(bounds, zoom);
    if (keys.length > maxTiles) {
      return const BuildingLookupResult(
        message: 'Zoom in closer to search this area.',
      );
    }
    final candidates = <String, BuildingCandidate>{};
    var failed = false;
    for (final key in keys) {
      final cacheKey = '${provider.cacheKey}:${key.z}/${key.x}/${key.y}';
      var tileCandidates = _tileCache.remove(cacheKey);
      if (tileCandidates == null) {
        final response = await (tileLoader ?? _loadTile)(provider, key);
        if (response is vt.TileResponseData) {
          tileCandidates = decodeTile(response.bytes, key);
          _tileCache[cacheKey] = tileCandidates;
          while (_tileCache.length > 128) {
            _tileCache.remove(_tileCache.keys.first);
          }
        } else if (response is vt.TileResponseError) {
          failed = true;
          continue;
        } else {
          tileCandidates = const [];
          _tileCache[cacheKey] = tileCandidates;
        }
      } else {
        _tileCache[cacheKey] = tileCandidates;
      }
      for (final candidate in tileCandidates) {
        candidates.putIfAbsent(candidate.id, () => candidate);
      }
    }
    final sorted = candidates.values.toList()
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    return BuildingLookupResult(
      candidates: sorted,
      hadTileFailure: failed,
      message: failed ? 'Some building tiles could not be loaded.' : null,
    );
  }

  static List<BuildingCandidate> decodeTile(
    Uint8List bytes,
    vt.TileKey key, {
    String layerName = sourceLayerName,
  }) {
    try {
      final uncompressed =
          bytes.length >= 2 && bytes[0] == 0x1f && bytes[1] == 0x8b
          ? Uint8List.fromList(gzip.decode(bytes))
          : bytes;
      final tile = mvt.VectorTile.fromBytes(bytes: uncompressed);
      mvt.VectorTileLayer? layer;
      for (final candidateLayer in tile.layers) {
        if (candidateLayer.name == layerName) {
          layer = candidateLayer;
          break;
        }
      }
      if (layer == null) return const [];
      final result = <BuildingCandidate>[];
      for (final feature in layer.features) {
        if (feature.type != mvt.VectorTileGeomType.POLYGON) continue;
        final properties = feature.decodeProperties();
        feature.decodeGeometry();
        final polygons = <List<List<List<double>>>>[];
        if (feature.geometryType == mvt.GeometryType.Polygon) {
          final geo = feature.toGeoJson<mvt.GeoJsonPolygon>(
            x: key.x,
            y: key.y,
            z: key.z,
          );
          final rings = geo?.geometry?.coordinates;
          if (rings != null) polygons.add(rings);
        } else if (feature.geometryType == mvt.GeometryType.MultiPolygon) {
          final geo = feature.toGeoJson<mvt.GeoJsonMultiPolygon>(
            x: key.x,
            y: key.y,
            z: key.z,
          );
          polygons.addAll(geo?.geometry?.coordinates ?? const []);
        }
        if (polygons.isEmpty) continue;
        final id = feature.id.toString();
        final name =
            properties['name']?.stringValue ??
            properties['name:en']?.stringValue;
        for (var i = 0; i < polygons.length; i++) {
          final rings = polygons[i];
          if (rings.isEmpty) continue;
          final points = rings.first
              .map((coordinate) {
                if (coordinate.length < 2) return null;
                final longitude = coordinate[0];
                final latitude = coordinate[1];
                if (!longitude.isFinite ||
                    !latitude.isFinite ||
                    longitude.abs() > 180 ||
                    latitude.abs() > 90) {
                  return null;
                }
                return LatLng(latitude, longitude);
              })
              .whereType<LatLng>()
              .toList();
          if (points.length < 3) continue;
          if (PlaceGeometry.validationError(points) != null) continue;
          final fallbackId = points
              .map(
                (point) =>
                    '${point.latitude.toStringAsFixed(6)},${point.longitude.toStringAsFixed(6)}',
              )
              .join(';');
          final stableId = id == '0' ? fallbackId : id;
          result.add(
            BuildingCandidate(
              id: polygons.length == 1 ? stableId : '$stableId:$i',
              name: name?.trim().isNotEmpty == true ? name!.trim() : 'Building',
              points: List.unmodifiable(points),
            ),
          );
        }
      }
      return result;
    } on Object {
      return const [];
    }
  }

  static String? _buildingSource(vt.Theme theme) {
    for (final layer in theme.layers) {
      if (layer.sourceLayer == sourceLayerName && layer.source != null) {
        return layer.source;
      }
    }
    return null;
  }

  Future<vt.TileResponse> _loadTile(
    vt.VectorTileProvider provider,
    vt.TileKey key,
  ) => provider.load(key);

  static List<vt.TileKey> _visibleTiles(LatLngBounds bounds, int zoom) {
    final n = 1 << zoom;
    final west = _tileX(bounds.west, n);
    final east = _tileX(bounds.east, n);
    final north = _tileY(bounds.north, n);
    final south = _tileY(bounds.south, n);
    final keys = <vt.TileKey>[];
    for (var x = west; x <= east; x++) {
      for (var y = north; y <= south; y++) {
        keys.add(vt.TileKey.wrapped(zoom, x, y));
      }
    }
    return keys;
  }

  static int _tileX(double longitude, int count) =>
      (((longitude + 180) / 360) * count).floor().clamp(0, count - 1);

  static int _tileY(double latitude, int count) {
    final clamped = latitude.clamp(-85.05112878, 85.05112878);
    final radians = clamped * 3.141592653589793 / 180;
    final y =
        (1 -
            (math.log(math.tan(radians) + 1 / math.cos(radians)) /
                3.141592653589793)) /
        2 *
        count;
    return y.floor().clamp(0, count - 1);
  }
}
