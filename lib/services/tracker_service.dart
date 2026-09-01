import 'dart:io';

import 'package:flutter/services.dart';
import 'package:traccar_client_sdk/traccar_client_sdk.dart';

class TrackingHealth {
  const TrackingHealth({
    required this.checked,
    required this.locationAlways,
    required this.batteryOptimizationOkay,
    required this.batteryOptimizationRelevant,
  });

  const TrackingHealth.unchecked()
    : checked = false,
      locationAlways = true,
      batteryOptimizationOkay = true,
      batteryOptimizationRelevant = false;

  factory TrackingHealth.fromMap(Map<Object?, Object?> map) {
    return TrackingHealth(
      checked: true,
      locationAlways: map['locationAlways'] == true,
      batteryOptimizationOkay: map['batteryOptimizationOkay'] == true,
      batteryOptimizationRelevant: map['batteryOptimizationRelevant'] == true,
    );
  }

  final bool checked;
  final bool locationAlways;
  final bool batteryOptimizationOkay;
  final bool batteryOptimizationRelevant;

  bool get needsLocation => checked && !locationAlways;
  bool get needsBattery =>
      checked && batteryOptimizationRelevant && !batteryOptimizationOkay;
  bool get hasWarning => needsLocation || needsBattery;
}

class TrackerService {
  TrackerService({TraccarClientSdk? sdk}) : _sdk = sdk ?? TraccarClientSdk();

  final TraccarClientSdk _sdk;

  static const _platform = MethodChannel(
    'com.oneupbyte.trakkar/tracking-support',
  );

  Future<void> configure({
    required Uri serverUrl,
    required String deviceId,
  }) async {
    final config = Config(
      serverUrl: serverUrl.toString(),
      deviceId: deviceId,
      location: const LocationConfig(
        distanceMeters: 25,
        intervalSeconds: 30,
        stopDetection: true,
      ),
      buffer: true,
      notification: const NotificationConfig(
        text: 'Trakkar is sharing your location',
      ),
    );
    await _sdk.init(config);
    await _sdk.setConfig(config);
  }

  Future<void> start() async {
    await _sdk.start();

    // The Traccar SDK requests Always authorization from an undetermined
    // state. If the user previously chose While Using, SDK 1.0.10 accepts
    // that status without requesting the one permitted upgrade to Always.
    // This bridge only requests authorization; Traccar SDK remains the sole
    // owner of location collection and background tracking.
    if (Platform.isIOS) {
      await _platform.invokeMethod<void>('requestAlwaysIfNeeded');
    }
  }

  Future<TrackingHealth> trackingHealth() async {
    if (!Platform.isAndroid && !Platform.isIOS) {
      return const TrackingHealth(
        checked: true,
        locationAlways: true,
        batteryOptimizationOkay: true,
        batteryOptimizationRelevant: false,
      );
    }
    final result = await _platform.invokeMapMethod<Object?, Object?>(
      'getTrackingHealth',
    );
    return TrackingHealth.fromMap(result ?? const <Object?, Object?>{});
  }

  Future<void> openLocationSettings() async {
    if (Platform.isAndroid || Platform.isIOS) {
      await _platform.invokeMethod<void>('openLocationSettings');
    }
  }

  Future<void> openBatterySettings() async {
    if (Platform.isAndroid) {
      await _platform.invokeMethod<void>('openBatterySettings');
    }
  }

  Future<void> stop() => _sdk.stop();

  Future<bool> isTracking() => _sdk.isTracking();

  Future<bool> sendNow() => _sdk.requestPosition();

  Future<List<LogEntry>> logs() => _sdk.getLogs();

  Future<void> clearLogs() => _sdk.clearLogs();
}
