import 'package:traccar_client_sdk/traccar_client_sdk.dart';

class TrackerService {
  TrackerService({TraccarClientSdk? sdk}) : _sdk = sdk ?? TraccarClientSdk();

  final TraccarClientSdk _sdk;

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

  Future<void> start() => _sdk.start();

  Future<void> stop() => _sdk.stop();

  Future<bool> isTracking() => _sdk.isTracking();

  Future<bool> sendNow() => _sdk.requestPosition();

  Future<List<LogEntry>> logs() => _sdk.getLogs();

  Future<void> clearLogs() => _sdk.clearLogs();
}
