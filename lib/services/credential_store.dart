import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../models/map_api_keys.dart';
import '../models/provisioning_config.dart';

class CredentialStore {
  CredentialStore({FlutterSecureStorage? storage})
    : _storage = storage ?? const FlutterSecureStorage();

  static const _clientUrl = 'provisioning.clientUrl';
  static const _managerUrl = 'provisioning.managerUrl';
  static const _managerUsername = 'provisioning.managerUsername';
  static const _managerPassword = 'provisioning.managerPassword';
  static const _googleMapsKey = 'map.googleMapsApiKey';
  static const _mapTilerKey = 'map.mapTilerApiKey';

  // Keys written by earlier builds. They are read once for migration and
  // deleted on reset.
  static const _legacyGeocodingKey = 'geocoding.apiKey';
  static const _legacySatelliteMapKey = 'map.satelliteApiKey';

  final FlutterSecureStorage _storage;

  Future<void> saveProvisioning(ProvisioningConfig config) async {
    final values = config.toStorage();
    await Future.wait(<Future<void>>[
      _storage.write(key: _clientUrl, value: values['clientUrl']),
      _storage.write(key: _managerUrl, value: values['managerUrl']),
      _storage.write(key: _managerUsername, value: values['managerUsername']),
      _storage.write(key: _managerPassword, value: values['managerPassword']),
    ]);
  }

  Future<ProvisioningConfig?> readProvisioning() async {
    final values = <String, String?>{
      'clientUrl': await _storage.read(key: _clientUrl),
      'managerUrl': await _storage.read(key: _managerUrl),
      'managerUsername': await _storage.read(key: _managerUsername),
      'managerPassword': await _storage.read(key: _managerPassword),
    };
    if (values.values.any((value) => value == null || value.isEmpty)) {
      return null;
    }
    return ProvisioningConfig.fromStorage(
      values.map((key, value) => MapEntry(key, value!)),
    );
  }

  Future<void> clearProvisioning() async {
    await Future.wait(<Future<void>>[
      _storage.delete(key: _clientUrl),
      _storage.delete(key: _managerUrl),
      _storage.delete(key: _managerUsername),
      _storage.delete(key: _managerPassword),
    ]);
  }

  /// Local cache of the map SDK keys shared through the manager account.
  /// The server copy is authoritative; this cache lets the map start before
  /// the manager session is established.
  Future<MapApiKeys> readMapKeys() async {
    final legacySatellite = await _storage.read(key: _legacySatelliteMapKey);
    return MapApiKeys(
      googleMaps: await _storage.read(key: _googleMapsKey) ?? '',
      mapTiler: await _storage.read(key: _mapTilerKey) ?? legacySatellite ?? '',
    );
  }

  Future<void> saveMapKeys(MapApiKeys keys) async {
    await Future.wait(<Future<void>>[
      _writeOrDelete(_googleMapsKey, keys.googleMaps),
      _writeOrDelete(_mapTilerKey, keys.mapTiler),
      _storage.delete(key: _legacySatelliteMapKey),
      _storage.delete(key: _legacyGeocodingKey),
    ]);
  }

  Future<void> clearMapKeys() => saveMapKeys(const MapApiKeys());

  Future<void> _writeOrDelete(String key, String value) async {
    if (value.trim().isEmpty) {
      await _storage.delete(key: key);
    } else {
      await _storage.write(key: key, value: value.trim());
    }
  }
}
