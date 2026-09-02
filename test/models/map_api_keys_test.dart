import 'package:flutter_test/flutter_test.dart';
import 'package:trakkar/models/map_api_keys.dart';
import 'package:trakkar/models/traccar_user.dart';

void main() {
  test('reads and trims keys from user attributes', () {
    final keys = MapApiKeys.fromAttributes(const {
      'trakkarGoogleMapsApiKey': '  google-key ',
      'trakkarMapTilerApiKey': 'maptiler-key',
      'unrelated': true,
    });

    expect(keys.googleMaps, 'google-key');
    expect(keys.mapTiler, 'maptiler-key');
    expect(keys.isEmpty, isFalse);
  });

  test('applyTo preserves unrelated attributes and removes cleared keys', () {
    const keys = MapApiKeys(googleMaps: 'g', mapTiler: '');
    final attributes = keys.applyTo(const {
      'trakkarMapTilerApiKey': 'old',
      'timezone': 'UTC',
    });

    expect(attributes, {'timezone': 'UTC', 'trakkarGoogleMapsApiKey': 'g'});
  });

  test('server keys win over an empty local cache during merge', () {
    const local = MapApiKeys(googleMaps: 'local-google');
    const server = MapApiKeys(mapTiler: 'server-maptiler');

    final merged = local.mergedWith(server);

    expect(merged.googleMaps, 'local-google');
    expect(merged.mapTiler, 'server-maptiler');
  });

  test('user attribute payload keeps every field and drops the password', () {
    final user = TraccarUser.fromJson(const {
      'id': 7,
      'name': 'Manager',
      'email': 'manager@example.com',
      'readonly': false,
      'password': null,
      'attributes': {'timezone': 'UTC'},
    });

    final payload = user.updateAttributesPayload(
      const MapApiKeys(googleMaps: 'g').applyTo(user.attributes),
    );

    expect(payload['id'], 7);
    expect(payload['readonly'], isFalse);
    expect(payload.containsKey('password'), isFalse);
    expect(payload['attributes'], {
      'timezone': 'UTC',
      'trakkarGoogleMapsApiKey': 'g',
    });
  });
}
