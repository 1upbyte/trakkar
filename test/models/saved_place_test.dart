import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:trakkar/models/saved_place.dart';

void main() {
  test('projects Traccar polygon WKT and retains its server identity', () {
    final place = SavedPlace.fromTraccar({
      'id': 12,
      'name': '  Office  ',
      'area': 'POLYGON((-78.7 35.7, -78.6 35.7, -78.6 35.8, -78.7 35.7))',
    });

    expect(place, isNotNull);
    expect(place!.id, 12);
    expect(place.name, 'Office');
    expect(place.geometryType, SavedPlaceGeometry.polygon);
    expect(place.wktArea, startsWith('POLYGON'));
    expect(place.points.first, const LatLng(35.7, -78.7));
  });

  test('projects supported point and circle geofences', () {
    final point = SavedPlace.fromTraccar({
      'id': 1,
      'name': 'Point',
      'area': 'POINT(-78.7 35.7)',
    });
    final circle = SavedPlace.fromTraccar({
      'id': 2,
      'name': 'Circle',
      'area': 'CIRCLE(35.7 -78.7, 100)',
    });

    expect(point?.geometryType, SavedPlaceGeometry.point);
    expect(circle?.geometryType, SavedPlaceGeometry.circle);
    expect(circle?.circleRadiusMeters, 100);
  });

  test('rejects malformed and out-of-range geofence geometry', () {
    expect(
      SavedPlace.fromTraccar({
        'id': 1,
        'name': 'Bad circle',
        'area': 'CIRCLE(999 0, 10)',
      }),
      isNull,
    );
    expect(
      SavedPlace.fromTraccar({
        'id': 1,
        'name': 'Bad polygon',
        'area': 'POLYGON((181 0, 182 0, 181 1, 181 0))',
      }),
      isNull,
    );
  });
}
