import 'dart:math' as math;

import 'package:latlong2/latlong.dart';

class PlaceGeometry {
  const PlaceGeometry._();

  static String? validationError(List<LatLng> vertices) {
    if (vertices.any(
      (point) =>
          !point.latitude.isFinite ||
          !point.longitude.isFinite ||
          point.latitude < -90 ||
          point.latitude > 90 ||
          point.longitude < -180 ||
          point.longitude > 180,
    )) {
      return 'Corners must be valid geographic coordinates.';
    }
    final ring = normalizedRing(vertices);
    if (ring.length < 3) return 'Add at least three different corners.';
    if (ring.toSet().length != ring.length) {
      return 'Each corner must be in a different location.';
    }
    if (_signedArea(ring).abs() < 1e-10) {
      return 'Corners must form an area, not a straight line.';
    }
    if (_selfIntersects(ring)) {
      return 'Boundary edges cannot cross each other.';
    }
    return null;
  }

  static List<LatLng> normalizedRing(List<LatLng> vertices) {
    final points = List<LatLng>.of(vertices);
    if (points.length > 1 && points.first == points.last) points.removeLast();
    return points;
  }

  static String toWktPolygon(List<LatLng> vertices) {
    final ring = normalizedRing(vertices);
    if (ring.isEmpty) return 'POLYGON(())';
    final closed = [...ring, ring.first];
    final coordinates = closed
        .map(
          (point) => '${_format(point.longitude)} ${_format(point.latitude)}',
        )
        .join(', ');
    return 'POLYGON(($coordinates))';
  }

  static bool _selfIntersects(List<LatLng> ring) {
    for (var i = 0; i < ring.length; i++) {
      final a = ring[i];
      final b = ring[(i + 1) % ring.length];
      for (var j = i + 1; j < ring.length; j++) {
        if (j == i ||
            j == (i + 1) % ring.length ||
            (j + 1) % ring.length == i) {
          continue;
        }
        if (_segmentsIntersect(a, b, ring[j], ring[(j + 1) % ring.length])) {
          return true;
        }
      }
    }
    return false;
  }

  static bool _segmentsIntersect(LatLng a, LatLng b, LatLng c, LatLng d) {
    final o1 = _orientation(a, b, c);
    final o2 = _orientation(a, b, d);
    final o3 = _orientation(c, d, a);
    final o4 = _orientation(c, d, b);
    return (o1 * o2 < 0 && o3 * o4 < 0) ||
        (o1 == 0 && _onSegment(a, b, c)) ||
        (o2 == 0 && _onSegment(a, b, d)) ||
        (o3 == 0 && _onSegment(c, d, a)) ||
        (o4 == 0 && _onSegment(c, d, b));
  }

  static double _orientation(LatLng a, LatLng b, LatLng c) =>
      (b.longitude - a.longitude) * (c.latitude - a.latitude) -
      (b.latitude - a.latitude) * (c.longitude - a.longitude);

  static bool _onSegment(LatLng a, LatLng b, LatLng point) =>
      point.longitude >= math.min(a.longitude, b.longitude) &&
      point.longitude <= math.max(a.longitude, b.longitude) &&
      point.latitude >= math.min(a.latitude, b.latitude) &&
      point.latitude <= math.max(a.latitude, b.latitude);

  static double _signedArea(List<LatLng> ring) {
    var area = 0.0;
    for (var i = 0; i < ring.length; i++) {
      final current = ring[i];
      final next = ring[(i + 1) % ring.length];
      area +=
          current.longitude * next.latitude - next.longitude * current.latitude;
    }
    return area / 2;
  }

  static String _format(double value) {
    final text = value.toStringAsFixed(7);
    return text
        .replaceFirst(RegExp(r'0+$'), '')
        .replaceFirst(RegExp(r'\.$'), '');
  }
}
