import '../../models/user_profile.dart';
import 'settings_repository.dart';

abstract interface class ProfileImageRepository {
  Future<String?> loadImageRef(String deviceUniqueId);
  Future<UserProfile> upload({
    required UserProfile profile,
    required String deviceUniqueId,
    required List<int> bytes,
    required String contentType,
  });
}

class TraccarProfileImageRepository implements ProfileImageRepository {
  const TraccarProfileImageRepository(this._api);

  final SettingsApiClient _api;

  Future<Map<String, dynamic>> _device(String uniqueId) async {
    final devices = await _api.getList('/api/devices');
    for (final device in devices) {
      if (device['uniqueId'] == uniqueId) return device;
    }
    throw const SettingsRepositoryFailure();
  }

  @override
  Future<String?> loadImageRef(String deviceUniqueId) async {
    final device = await _device(deviceUniqueId);
    final attributes = device['attributes'];
    final filename = attributes is Map ? attributes['deviceImage'] : null;
    if (filename is! String || filename.isEmpty) return null;
    return 'traccar-media:$deviceUniqueId/$filename';
  }

  @override
  Future<UserProfile> upload({
    required UserProfile profile,
    required String deviceUniqueId,
    required List<int> bytes,
    required String contentType,
  }) async {
    if (bytes.isEmpty || bytes.length > 500000) {
      throw const SettingsRepositoryFailure();
    }
    final device = await _device(deviceUniqueId);
    final deviceId = (device['id'] as num?)?.toInt();
    if (deviceId == null) throw const SettingsRepositoryFailure();
    final filename = await _api.uploadImage(deviceId, bytes, contentType);
    final attributes = device['attributes'] is Map
        ? Map<String, dynamic>.from(device['attributes'] as Map)
        : <String, dynamic>{};
    attributes['deviceImage'] = filename;
    final savedDevice = await _api.putObject('/api/devices/$deviceId', {
      ...device,
      'attributes': attributes,
    });
    final savedAttributes = savedDevice['attributes'];
    final savedFilename = savedAttributes is Map
        ? savedAttributes['deviceImage']
        : null;
    if (savedFilename is! String || savedFilename != filename) {
      throw const SettingsRepositoryFailure();
    }
    return profile.copyWith(
      profileImageRef: 'traccar-media:$deviceUniqueId/$filename',
    );
  }
}
