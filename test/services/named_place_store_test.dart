import 'package:flutter_test/flutter_test.dart';
import 'package:trakkar/models/named_place.dart';
import 'package:trakkar/services/named_place_store.dart';

void main() {
  test('nearest returns a named place only inside its radius', () {
    const home = NamedPlace(
      id: 'home',
      name: 'Home',
      latitude: 40.7128,
      longitude: -74.006,
      radiusMeters: 200,
    );

    expect(NamedPlaceStore.nearest(const [home], 40.713, -74.006), same(home));
    expect(NamedPlaceStore.nearest(const [home], 40.72, -74.006), isNull);
  });
}
