import 'dart:math' as math;

import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../models/map_view_state.dart';

class InitialMapCamera {
  const InitialMapCamera({required this.center, required this.zoom});
  final LatLng center;
  final double zoom;
}

class MapCameraPolicy {
  const MapCameraPolicy({this.maximumAutomaticExtentMeters = 3218.688});

  final double maximumAutomaticExtentMeters;

  InitialMapCamera initialCamera(
    Iterable<LatLng> positions, {
    double width = 390,
    double height = 720,
  }) {
    final points = positions.toList();
    if (points.isEmpty) {
      return const InitialMapCamera(center: LatLng(20, 0), zoom: 2);
    }
    if (points.length == 1) {
      return InitialMapCamera(center: points.single, zoom: 15);
    }
    final south = points.map((p) => p.latitude).reduce(math.min);
    final north = points.map((p) => p.latitude).reduce(math.max);
    final west = points.map((p) => p.longitude).reduce(math.min);
    final east = points.map((p) => p.longitude).reduce(math.max);
    final center = LatLng((south + north) / 2, (west + east) / 2);
    final cosLatitude = math.max(
      0.05,
      math.cos(center.latitude * math.pi / 180),
    );
    final rawWidth = (east - west) * 111320 * cosLatitude;
    final rawHeight = (north - south) * 111320;
    final cappedWidth = math.min(rawWidth, maximumAutomaticExtentMeters);
    final cappedHeight = math.min(rawHeight, maximumAutomaticExtentMeters);
    final visibleWidth = math.max(150.0, width - 72);
    final visibleHeight = math.max(150.0, height - 220);
    const worldPixelsAtZoomZero = 256.0;
    final widthZoom =
        math.log(
          visibleWidth *
              40075016.686 *
              cosLatitude /
              (worldPixelsAtZoomZero * math.max(1, cappedWidth)),
        ) /
        math.ln2;
    final heightZoom =
        math.log(
          visibleHeight *
              40075016.686 /
              (worldPixelsAtZoomZero * math.max(1, cappedHeight)),
        ) /
        math.ln2;
    final zoom = math.min(widthZoom, heightZoom).clamp(2.0, 17.0).toDouble();
    return InitialMapCamera(center: center, zoom: zoom);
  }

  MapViewSnapshot snapshot(MapCamera camera) => MapViewSnapshot(
    center: camera.center,
    zoom: camera.zoom,
    rotation: camera.rotation,
  );
}
