import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:latlong2/latlong.dart';

import '../app_state.dart';
import '../models/named_place.dart';
import '../models/provisioning_config.dart';
import '../models/traccar_device.dart';
import '../models/traccar_position.dart';
import '../services/tracker_service.dart';

/// Whether to skip server setup and run the real UI against sample data.
///
/// Enable it with `--dart-define=TRAKKAR_DEMO=true`, or, in the iOS simulator,
/// by launching with the `TRAKKAR_DEMO=1` environment variable. The
/// "Runner Demo" Xcode scheme sets that variable for the simulator.
Future<bool> resolveDemoMode() async {
  if (const bool.fromEnvironment('TRAKKAR_DEMO')) return true;
  if (kReleaseMode || kIsWeb || defaultTargetPlatform != TargetPlatform.iOS) {
    return false;
  }
  try {
    // Dart cannot read Xcode scheme variables; the native side reports them.
    return await const MethodChannel('com.oneupbyte.trakkar/diagnostics')
            .invokeMethod<bool>('demoMode') ??
        false;
  } on Object {
    return false;
  }
}

/// An [AppState] that starts signed in with fake data and never contacts a
/// Traccar server or starts native location tracking.
class DemoAppState extends AppState {
  DemoAppState({super.preferences});

  static const _ownUniqueId = 'demo-you';

  @override
  Future<void> bootstrap() async {
    // Theme and map appearance still persist so Settings behaves normally.
    await loadLocalPreferences();
    _loadSampleData();
  }

  void _loadSampleData() {
    final now = DateTime.now();
    provisioning = ProvisioningConfig(
      clientUrl: Uri.parse('https://client.demo.invalid'),
      managerUrl: Uri.parse('https://manager.demo.invalid'),
      liveTrackingUrl: Uri.parse('https://live.demo.invalid'),
      managerUsername: 'demo',
      managerPassword: 'demo',
    );
    firstName = 'You';
    deviceUsername = _ownUniqueId;
    tracking = true;
    liveConnected = true;
    busy = false;
    lastError = null;
    trackingHealth = const TrackingHealth(
      checked: true,
      locationAlways: true,
      activityRecognitionOkay: true,
      batteryOptimizationOkay: true,
      batteryOptimizationRelevant: false,
    );
    devices = [
      _device(1, 'You', _ownUniqueId, now),
      _device(2, 'Alex', 'demo-alex', now),
      _device(3, 'Sam', 'demo-sam', now),
      _device(4, 'Jordan', 'demo-jordan', now),
      _device(5, 'Riley', 'demo-riley', now, status: 'offline'),
    ];
    positions = {
      // At home, fresh fix.
      1: TraccarPosition(
        id: 101,
        deviceId: 1,
        latitude: 40.7812,
        longitude: -73.9665,
        valid: true,
        fixTime: now,
        accuracy: 8,
        address: '1 W 85th St, New York, NY',
      ),
      // Driving across midtown (shows the driving badge at >= 10 mph).
      2: TraccarPosition(
        id: 102,
        deviceId: 2,
        latitude: 40.7549,
        longitude: -73.9840,
        valid: true,
        fixTime: now.subtract(const Duration(seconds: 5)),
        speed: 22,
        course: 45,
        accuracy: 12,
        address: '6th Ave & W 42nd St, New York, NY',
        attributes: const {'motion': true},
      ),
      // Inside the "Work" polygon, a few minutes old.
      3: TraccarPosition(
        id: 103,
        deviceId: 3,
        latitude: 40.7527,
        longitude: -73.9772,
        valid: true,
        fixTime: now.subtract(const Duration(minutes: 4)),
        accuracy: 15,
        address: 'Grand Central Terminal, New York, NY',
      ),
      // Close to Sam so the two cluster at lower zoom levels.
      4: TraccarPosition(
        id: 104,
        deviceId: 4,
        latitude: 40.7531,
        longitude: -73.9765,
        valid: true,
        fixTime: now.subtract(const Duration(minutes: 20)),
        accuracy: 20,
        address: '89 E 42nd St, New York, NY',
      ),
      // Offline with an old fix across the river.
      5: TraccarPosition(
        id: 105,
        deviceId: 5,
        latitude: 40.6782,
        longitude: -73.9442,
        valid: true,
        fixTime: now.subtract(const Duration(hours: 6)),
        accuracy: 30,
        address: 'Crown Heights, Brooklyn, NY',
      ),
    };
    deviceImages = const {};
    namedPlaces = const [
      NamedPlace(
        id: '1',
        name: 'Home',
        latitude: 40.7812,
        longitude: -73.9665,
        radiusMeters: 120,
        serverBacked: true,
      ),
      NamedPlace(
        id: '2',
        name: 'Work',
        latitude: 40.7527,
        longitude: -73.9772,
        boundary: [
          LatLng(40.7536, -73.9785),
          LatLng(40.7536, -73.9760),
          LatLng(40.7518, -73.9760),
          LatLng(40.7518, -73.9785),
        ],
        serverBacked: true,
      ),
      NamedPlace(
        id: '3',
        name: 'Gym',
        latitude: 40.6782,
        longitude: -73.9442,
        radiusMeters: 200,
        serverBacked: true,
      ),
    ];
    phase = AppPhase.ready;
    notifyListeners();
  }

  TraccarDevice _device(
    int id,
    String name,
    String uniqueId,
    DateTime now, {
    String status = 'online',
  }) => TraccarDevice(
    id: id,
    name: name,
    uniqueId: uniqueId,
    status: status,
    positionId: 100 + id,
    lastUpdate: now,
    raw: {'id': id, 'name': name, 'uniqueId': uniqueId},
  );

  // Everything below replaces server, socket, and native SDK calls.

  @override
  void setAppForeground(bool visible) {}

  @override
  Future<void> refresh() async {}

  @override
  Future<void> refreshTrackingHealth() async {}

  @override
  Future<void> setTracking(bool enabled) async {
    tracking = enabled;
    notifyListeners();
  }

  @override
  Future<bool> sendPositionNow() async => true;

  @override
  Future<void> openLocationSettings() async {}

  @override
  Future<void> openBatterySettings() async {}

  @override
  Future<String> arrivalSummary(TraccarPosition position) async =>
      position.isMoving ? 'Currently moving' : 'Here since 2h ago';

  @override
  Future<String> reverseGeocode(TraccarPosition position) async =>
      friendlyPlaceFor(position) ??
      position.address ??
      '${position.latitude.toStringAsFixed(4)}, '
          '${position.longitude.toStringAsFixed(4)}';

  @override
  Future<void> addNamedPlace({
    required String name,
    required double latitude,
    required double longitude,
    double radiusMeters = 150,
    List<LatLng> boundary = const <LatLng>[],
  }) async {
    final cleanName = name.trim();
    if (cleanName.isEmpty) throw const FormatException('Enter a place name.');
    if (boundary.isNotEmpty && boundary.length < 3) {
      throw const FormatException('Draw at least 3 corners for the place.');
    }
    final nextId =
        namedPlaces
            .map((place) => int.tryParse(place.id) ?? 0)
            .fold(0, (a, b) => a > b ? a : b) +
        1;
    namedPlaces = [
      ...namedPlaces,
      NamedPlace(
        id: '$nextId',
        name: cleanName,
        latitude: latitude,
        longitude: longitude,
        radiusMeters: radiusMeters,
        boundary: boundary,
        serverBacked: true,
      ),
    ];
    notifyListeners();
  }

  @override
  Future<void> deleteNamedPlace(String id) async {
    namedPlaces = namedPlaces.where((place) => place.id != id).toList();
    notifyListeners();
  }

  @override
  Future<void> updateProfilePicture(Uint8List bytes, String contentType) async {
    final device = ownDevice;
    if (device == null) return;
    deviceImages = {...deviceImages, device.id: bytes};
    notifyListeners();
  }

  /// Restores the sample data instead of returning to server setup.
  @override
  Future<void> resetApp() async => _loadSampleData();
}
