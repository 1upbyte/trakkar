import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_vector_tiles/flutter_map_vector_tiles.dart';
// The package does not export its MVT decoder. Its version is pinned and the
// conversion is covered by real-tile and synthetic-geometry regression tests.
// ignore: implementation_imports
import 'package:flutter_map_vector_tiles/src/mvt/mvt_decoder.dart';
// ignore: implementation_imports
import 'package:flutter_map_vector_tiles/src/mvt/mvt_tile.dart';

import 'package:latlong2/latlong.dart';

import 'named_place_store.dart';

class BuildingFootprint {
  const BuildingFootprint({
    required this.id,
    required this.boundary,
    this.name = '',
    this.holes = const [],
  });

  final String id;
  final String name;
  final List<LatLng> boundary;
  final List<List<LatLng>> holes;

  bool contains(LatLng point) =>
      NamedPlaceStore.polygonContains(
        boundary,
        point.latitude,
        point.longitude,
      ) &&
      !holes.any(
        (hole) => NamedPlaceStore.polygonContains(
          hole,
          point.latitude,
          point.longitude,
        ),
      );
}

/// Reads the same native vector tiles used by the street map. No separate
/// geospatial service or per-tap network lookup is required.
class BuildingLookup {
  final Map<String, List<BuildingFootprint>> _cache = {};
  final Map<String, Future<List<BuildingFootprint>>> _pending = {};

  Future<List<BuildingFootprint>> inBounds(
    VectorTileProvider provider,
    LatLngBounds bounds,
  ) async {
    final z = provider.maximumZoom;
    final nw = tileAt(bounds.northWest, z);
    final se = tileAt(bounds.southEast, z);
    final width = ((se.x - nw.x) % (1 << z)) + 1;
    final height = se.y - nw.y + 1;
    if (width * height > 16) {
      throw const FormatException('Zoom in to see selectable buildings.');
    }
    final tiles = [
      for (var dx = 0; dx < width; dx++)
        for (var y = nw.y; y <= se.y; y++) TileKey.wrapped(z, nw.x + dx, y),
    ];
    final results = await Future.wait(
      tiles.map((tile) => _load(provider, tile)),
    );
    // Buffered neighboring tiles can contain the same footprint.
    final unique = <String, BuildingFootprint>{};
    for (final building in results.expand((tile) => tile)) {
      if (!LatLngBounds.fromPoints(building.boundary).isOverlapping(bounds)) {
        continue;
      }
      final old = unique[building.id];
      if (old == null ||
          polygonArea(building.boundary) > polygonArea(old.boundary)) {
        unique[building.id] = building;
      }
    }
    return unique.values.toList();
  }

  Future<List<BuildingFootprint>> _load(
    VectorTileProvider provider,
    TileKey tile,
  ) async {
    final key = '${provider.cacheKey}/$tile';
    final cached = _cache[key];
    if (cached != null) return cached;
    final existing = _pending[key];
    if (existing != null) return existing;
    final request = () async {
      final response = await provider
          .load(tile)
          .timeout(const Duration(seconds: 15));
      final List<BuildingFootprint> buildings;
      if (response is TileResponseData) {
        buildings = await compute(_decodeTile, (
          bytes: response.bytes,
          tile: tile,
        ));
      } else if (response is TileResponseNotFound) {
        buildings = [];
      } else {
        throw const FormatException(
          'Building outlines could not be loaded. Try again.',
        );
      }
      if (_cache.length >= 12) _cache.remove(_cache.keys.first);
      _cache[key] = buildings;
      return buildings;
    }();
    _pending[key] = request;
    try {
      return await request;
    } finally {
      _pending.remove(key);
    }
  }

  static TileKey tileAt(LatLng point, int z) {
    final n = 1 << z;
    final latitude =
        point.latitude.clamp(-85.05112878, 85.05112878) * math.pi / 180;
    final mercator = math.log(math.tan(latitude) + 1 / math.cos(latitude));
    return TileKey.wrapped(
      z,
      ((point.longitude + 180) / 360 * n).floor(),
      ((1 - mercator / math.pi) / 2 * n).floor().clamp(0, n - 1),
    );
  }
}

List<BuildingFootprint> _decodeTile(({Uint8List bytes, TileKey tile}) data) =>
    decodeBuildingTile(data.bytes, data.tile);

/// MVT rings are implicitly closed and use tile-local x/y coordinates, not
/// the closed latitude/longitude arrays returned by Overpass.
List<BuildingFootprint> decodeBuildingTile(Uint8List bytes, TileKey tile) {
  final decoded = decodeMvt(bytes);
  final layer = decoded.layer('building');
  if (layer == null) return [];
  LatLng coordinate(double x, double y, int extent) {
    final n = (1 << tile.z).toDouble();
    final worldY = (tile.y + y / extent) / n;
    final mercator = math.pi * (1 - 2 * worldY);
    return LatLng(
      math.atan((math.exp(mercator) - math.exp(-mercator)) / 2) * 180 / math.pi,
      (tile.x + x / extent) / n * 360 - 180,
    );
  }

  final poiLayer = decoded.layer('poi');
  final pois = <({LatLng point, String name})>[];
  if (poiLayer != null) {
    for (final feature in poiLayer.features) {
      final properties = feature.decodeProperties(poiLayer);
      final name = (properties['name'] ?? properties['name:en'] ?? '')
          .toString();
      if (name.isEmpty) continue;
      for (final part in feature.parts) {
        if (part.length >= 2) {
          pois.add((
            point: coordinate(part[0], part[1], poiLayer.extent),
            name: name,
          ));
        }
      }
    }
  }
  final result = <BuildingFootprint>[];
  for (
    var featureIndex = 0;
    featureIndex < layer.features.length;
    featureIndex++
  ) {
    final feature = layer.features[featureIndex];
    if (feature.type != MvtGeomType.polygon) continue;
    final properties = feature.decodeProperties(layer);
    for (var i = 0; i < feature.parts.length; i++) {
      if (feature.ringAreas[i] <= 0 || feature.parts[i].length < 6) continue;
      List<LatLng> ring(int index) => [
        for (var p = 0; p < feature.parts[index].length; p += 2)
          coordinate(
            feature.parts[index][p],
            feature.parts[index][p + 1],
            layer.extent,
          ),
      ];
      final holes = <List<LatLng>>[];
      for (
        var h = i + 1;
        h < feature.parts.length && feature.ringAreas[h] < 0;
        h++
      ) {
        holes.add(ring(h));
      }
      final boundary = ring(i);
      // Building tiles may group many unrelated footprints under one feature
      // ID. Geometry identifies a ring consistently across buffered tile copies.
      final vertices =
          boundary
              .map(
                (p) =>
                    '${p.latitude.toStringAsFixed(7)},${p.longitude.toStringAsFixed(7)}',
              )
              .toList()
            ..sort();
      final id = vertices.join(';');
      final footprint = BuildingFootprint(
        id: id,
        boundary: boundary,
        holes: holes,
      );
      final name =
          (properties['name'] ??
                  properties['name:en'] ??
                  pois
                      .where((poi) => footprint.contains(poi.point))
                      .firstOrNull
                      ?.name ??
                  '')
              .toString();
      result.add(
        BuildingFootprint(id: id, boundary: boundary, holes: holes, name: name),
      );
    }
  }
  return result;
}

double polygonArea(List<LatLng> points) {
  var sum = 0.0;
  for (var i = 0; i < points.length; i++) {
    final a = points[i];
    final b = points[(i + 1) % points.length];
    sum += a.longitude * b.latitude - b.longitude * a.latitude;
  }
  return sum.abs() / 2;
}

/// A single enclosing area includes the space between selected buildings.
List<LatLng> buildingBoundary(List<BuildingFootprint> buildings) {
  if (buildings.isEmpty) return [];
  if (buildings.length == 1) return [...buildings.single.boundary];
  final points = buildings.expand((b) => b.boundary).toSet().toList()
    ..sort((a, b) {
      final x = a.longitude.compareTo(b.longitude);
      return x == 0 ? a.latitude.compareTo(b.latitude) : x;
    });
  double cross(LatLng a, LatLng b, LatLng c) =>
      (b.longitude - a.longitude) * (c.latitude - a.latitude) -
      (b.latitude - a.latitude) * (c.longitude - a.longitude);
  List<LatLng> half(Iterable<LatLng> sorted) {
    final result = <LatLng>[];
    for (final point in sorted) {
      while (result.length >= 2 &&
          cross(result[result.length - 2], result.last, point) <= 0) {
        result.removeLast();
      }
      result.add(point);
    }
    return result;
  }

  final lower = half(points)..removeLast();
  final upper = half(points.reversed)..removeLast();
  return [...lower, ...upper];
}
