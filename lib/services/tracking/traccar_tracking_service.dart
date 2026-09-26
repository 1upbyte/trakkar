import 'dart:math';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:traccar_client_sdk/traccar_client_sdk.dart';

import '../../models/login_details.dart';
import '../settings/sdk_configuration_reset_bridge.dart';

class TraccarTrackingService implements TrackingResetService {
  TraccarTrackingService({
    TraccarClientSdk? sdk,
    FlutterSecureStorage? storage,
    SdkConfigurationResetBridge? resetBridge,
  }) : _sdk = sdk ?? TraccarClientSdk(),
       _storage = storage ?? const FlutterSecureStorage(),
       _resetBridge =
           resetBridge ?? const MethodChannelSdkConfigurationResetBridge();

  final TraccarClientSdk _sdk;
  final FlutterSecureStorage _storage;
  final SdkConfigurationResetBridge _resetBridge;
  bool _isStarted = false;
  bool _wasStartedBeforeStop = false;
  static const _deviceIdKey = 'tracking.deviceId';

  Future<void> configure(LoginDetailsDraft details) async {
    final deviceId = await deviceUniqueId();
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

  Future<void> start() async {
    await _sdk.start();
    _isStarted = true;
  }

  @override
  Future<void> stop() async {
    _wasStartedBeforeStop = _isStarted;
    await _sdk.stop();
    _isStarted = false;
  }

  @override
  Future<void> resumeAfterFailedReset() async {
    if (!_wasStartedBeforeStop) return;
    _wasStartedBeforeStop = false;
    await start();
  }

  @override
  Future<void> clearConfiguration() async {
    await _resetBridge.clearConfiguration();
    await _storage.delete(key: _deviceIdKey);
  }

  Future<bool> requestPosition() => _sdk.requestPosition();

  Future<String> deviceUniqueId() async {
    var deviceId = await _storage.read(key: _deviceIdKey);
    if (deviceId == null) {
      final random = Random.secure();
      deviceId = List<int>.generate(
        16,
        (_) => random.nextInt(256),
      ).map((byte) => byte.toRadixString(16).padLeft(2, '0')).join();
      await _storage.write(key: _deviceIdKey, value: deviceId);
    }
    return deviceId;
  }
}
