import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../models/provisioning_config.dart';

class CredentialStore {
  CredentialStore({FlutterSecureStorage? storage})
    : _storage = storage ?? const FlutterSecureStorage();

  static const _clientUrl = 'provisioning.clientUrl';
  static const _liveTrackingUrl = 'provisioning.liveTrackingUrl';
  static const _managerUrl = 'provisioning.managerUrl';
  static const _managerUsername = 'provisioning.managerUsername';
  static const _managerPassword = 'provisioning.managerPassword';

  final FlutterSecureStorage _storage;

  Future<void> saveProvisioning(ProvisioningConfig config) async {
    final values = config.toStorage();
    await Future.wait(<Future<void>>[
      _storage.write(key: _clientUrl, value: values['clientUrl']),
      _storage.write(key: _managerUrl, value: values['managerUrl']),
      _storage.write(key: _liveTrackingUrl, value: values['liveTrackingUrl']),
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
    values['liveTrackingUrl'] = await _storage.read(key: _liveTrackingUrl) ?? '';
    return ProvisioningConfig.fromStorage(
      values.map((key, value) => MapEntry(key, value!)),
    );
  }

  Future<void> clearProvisioning() async {
    await Future.wait(<Future<void>>[
      _storage.delete(key: _clientUrl),
      _storage.delete(key: _managerUrl),
      _storage.delete(key: _liveTrackingUrl),
      _storage.delete(key: _managerUsername),
      _storage.delete(key: _managerPassword),
    ]);
  }
}
