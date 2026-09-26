import 'package:latlong2/latlong.dart';

class SavedPlace {
  const SavedPlace({
    required this.id,
    required this.name,
    required this.points,
    this.circleRadiusMeters,
    this.wktArea,
    this.source = SavedPlaceSource.existing,
  });

  final int id;
  final String name;
  final List<LatLng> points;
  final double? circleRadiusMeters;
  final String? wktArea;
  final SavedPlaceSource source;

  SavedPlaceGeometry get geometryType => circleRadiusMeters != null
      ? SavedPlaceGeometry.circle
      : points.length < 3
      ? SavedPlaceGeometry.point
      : SavedPlaceGeometry.polygon;

  bool contains(LatLng point) {
    if (circleRadiusMeters case final radius?) {
      return const Distance().as(LengthUnit.Meter, points.first, point) <=
          radius;
    }
    if (points.length == 1) {
      return const Distance().as(LengthUnit.Meter, points.first, point) <= 1;
    }
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

  static SavedPlace? fromTraccar(Map<String, dynamic> json) {
    final area = json['area'];
    final name = (json['name'] as String?)?.trim() ?? '';
    if (area is! String || name.isEmpty) return null;
    final circle = RegExp(
      r'^\s*CIRCLE\s*\(\s*(-?[\d.]+)\s+(-?[\d.]+)\s*,\s*([\d.]+)\s*\)\s*$',
      caseSensitive: false,
    ).firstMatch(area);
    if (circle != null) {
      final latitude = double.tryParse(circle[1]!);
      final longitude = double.tryParse(circle[2]!);
      final radius = double.tryParse(circle[3]!);
      if (latitude == null ||
          longitude == null ||
          radius == null ||
          !latitude.isFinite ||
          !longitude.isFinite ||
          !radius.isFinite ||
          latitude.abs() > 90 ||
          longitude.abs() > 180 ||
          radius <= 0) {
        return null;
      }
      return SavedPlace(
        id: (json['id'] as num?)?.toInt() ?? 0,
        name: name,
        points: [LatLng(latitude, longitude)],
        circleRadiusMeters: radius,
        wktArea: area,
      );
    }
    final point = RegExp(
      r'^\s*POINT\s*\(\s*(-?[\d.]+)\s+(-?[\d.]+)\s*\)\s*$',
      caseSensitive: false,
    ).firstMatch(area);
    if (point != null) {
      final longitude = double.tryParse(point[1]!);
      final latitude = double.tryParse(point[2]!);
      if (latitude == null ||
          longitude == null ||
          !latitude.isFinite ||
          !longitude.isFinite ||
          latitude.abs() > 90 ||
          longitude.abs() > 180) {
        return null;
      }
      return SavedPlace(
        id: (json['id'] as num?)?.toInt() ?? 0,
        name: name,
        points: [LatLng(latitude, longitude)],
        wktArea: area,
      );
    }
    final body = RegExp(
      r'POLYGON\s*\(\((.*)\)\)',
      caseSensitive: false,
    ).firstMatch(area)?.group(1);
    if (body == null) return null;
    final points = body.split(',').map((pair) {
      final parts = pair.trim().split(RegExp(r'\s+'));
      if (parts.length < 2) return null;
      final longitude = double.tryParse(parts[0]);
      final latitude = double.tryParse(parts[1]);
      if (latitude == null ||
          longitude == null ||
          !latitude.isFinite ||
          !longitude.isFinite ||
          latitude.abs() > 90 ||
          longitude.abs() > 180) {
        return null;
      }
      return LatLng(latitude, longitude);
    }).toList();
    if (points.any((point) => point == null) || points.length < 4) return null;
    return SavedPlace(
      id: (json['id'] as num?)?.toInt() ?? 0,
      name: name,
      points: points.cast<LatLng>(),
      wktArea: area,
    );
  }
}

enum SavedPlaceGeometry { point, circle, polygon }

enum SavedPlaceSource { auto, manual, existing }
