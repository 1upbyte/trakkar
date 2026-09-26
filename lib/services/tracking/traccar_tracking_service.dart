import 'dart:math';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:traccar_client_sdk/traccar_client_sdk.dart';

import '../../models/login_details.dart';

class TraccarTrackingService {
  TraccarTrackingService({TraccarClientSdk? sdk, FlutterSecureStorage? storage})
    : _sdk = sdk ?? TraccarClientSdk(),
      _storage = storage ?? const FlutterSecureStorage();

  final TraccarClientSdk _sdk;
  final FlutterSecureStorage _storage;
  static const _deviceIdKey = 'tracking.deviceId';

  Future<void> configure(LoginDetailsDraft details) async {
    var deviceId = await _storage.read(key: _deviceIdKey);
    if (deviceId == null) {
      final random = Random.secure();
      deviceId = List<int>.generate(
        16,
        (_) => random.nextInt(256),
      ).map((byte) => byte.toRadixString(16).padLeft(2, '0')).join();
      await _storage.write(key: _deviceIdKey, value: deviceId);
    }
    final config = Config(
      serverUrl: details.clientUrl,
      deviceId: deviceId,
      location: const LocationConfig(
        accuracy: Accuracy.high,
        intervalSeconds: 300,
        distanceMeters: 75,
      ),
      buffer: true,
    );
    await _sdk.init(config);
    await _sdk.setConfig(config);
  }

  Future<void> start() => _sdk.start();
  Future<void> stop() => _sdk.stop();
  Future<bool> requestPosition() => _sdk.requestPosition();
}
