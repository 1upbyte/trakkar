import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:trakkar/features/map/place_labels_layer.dart';
import 'package:trakkar/models/saved_place.dart';

void main() {
  const layer = PlaceLabelsLayer();
  final places = [
    const SavedPlace(
      id: 1,
      name: 'Downtown',
      points: [LatLng(35.7, -78.6), LatLng(35.71, -78.59)],
      circleRadiusMeters: 1000,
    ),
    const SavedPlace(
      id: 2,
      name: 'Park',
      points: [LatLng(35.705, -78.595)],
      circleRadiusMeters: 50,
    ),
    const SavedPlace(
      id: 3,
      name: 'Far Place',
      points: [LatLng(36, -78)],
      circleRadiusMeters: 50,
    ),
  ];

  test('large place labels appear at wider zoom than small places', () {
    expect(layer.build(places: places, zoom: 9, latitude: 35.7), hasLength(1));
    expect(
      layer.build(places: places, zoom: 14, latitude: 35.7).length,
      greaterThan(1),
    );
  });

  test('close labels are decluttered while distant labels remain visible', () {
    final labels = layer.build(places: places, zoom: 15, latitude: 35.7);
    expect(labels.length, 2);
  });
}
