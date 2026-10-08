import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'models/named_place.dart';
import 'models/provisioning_config.dart';
import 'models/theme_preference.dart';
import 'models/traccar_device.dart';
import 'models/traccar_position.dart';
import 'services/credential_store.dart';
import 'services/driving_status_tracker.dart';
import 'services/named_place_store.dart';
import 'services/traccar_api.dart';
import 'services/tracker_service.dart';
import 'user_facing_error.dart';

enum AppPhase { loading, onboarding, ready }

class DeviceConflictException implements Exception {
  const DeviceConflictException(this.device);
  final TraccarDevice device;
}

class AppState extends ChangeNotifier {
  AppState({
    CredentialStore? credentialStore,
    NamedPlaceStore? namedPlaceStore,
    TrackerService? trackerService,
    SharedPreferencesAsync? preferences,
  }) : _credentialStore = credentialStore ?? CredentialStore(),
       _namedPlaceStore = namedPlaceStore ?? NamedPlaceStore(),
       _preferences = preferences ?? SharedPreferencesAsync(),
       _tracker = trackerService ?? TrackerService();

  static const _firstNameKey = 'profile.firstName';
  static const _deviceUsernameKey = 'profile.deviceUsername';
  static const _trackingWantedKey = 'tracking.wanted';
  static const _satelliteZoomKey = 'map.satelliteZoom';
  static const _satelliteAlwaysKey = 'map.satelliteAlways';
  Future<void> _appearanceSave = Future.value();
  static const _darkMapKey = 'map.darkMode';
  static const _satelliteAutoKey = 'map.satelliteAutoAtStreetZoom';
  static const _themePreferenceKey = 'appearance.theme';

  final CredentialStore _credentialStore;
  final NamedPlaceStore _namedPlaceStore;
  final SharedPreferencesAsync _preferences;
  final TrackerService _tracker;
  final DrivingStatusTracker _drivingStatus = DrivingStatusTracker();

  AppPhase phase = AppPhase.loading;
  ProvisioningConfig? pendingProvisioning;
  ProvisioningConfig? provisioning;
  TraccarApi? _api;
  StreamSubscription<Map<String, dynamic>>? _liveSubscription;
  Timer? _reconnectTimer;
  Timer? _drivingExpiryTimer;
  bool _appForeground = true;
  int _liveGeneration = 0;
  int _reconnectAttempts = 0;

  String firstName = '';
  String deviceUsername = '';
  bool tracking = false;
  bool liveConnected = false;
  bool busy = false;
  String? lastError;
  String? exitAlert;
  TrackingHealth trackingHealth = const TrackingHealth.unchecked();

  List<TraccarDevice> devices = const [];
  Map<int, TraccarPosition> positions = const {};
  Map<int, Uint8List> deviceImages = const {};
  List<NamedPlace> namedPlaces = const [];
  double satelliteZoom = 19;
  bool satelliteAlways = false;
  bool darkMap = false;
  bool satelliteAutoAtStreetZoom = true;
  String mapTilerApiKey = '';
  ThemePreference themePreference = ThemePreference.system;

  TraccarDevice? get ownDevice {
    for (final device in devices) {
      if (device.uniqueId == deviceUsername) return device;
    }
    return null;
  }

  Future<void> bootstrap() async {
    namedPlaces = await _namedPlaceStore.load();
    satelliteAutoAtStreetZoom =
        await _preferences.getBool(_satelliteAutoKey) ?? true;
    satelliteZoom = (await _preferences.getDouble(_satelliteZoomKey) ?? 19)
        .clamp(2, 21);
    satelliteAlways = await _preferences.getBool(_satelliteAlwaysKey) ?? false;
    darkMap = await _preferences.getBool(_darkMapKey) ?? false;
    final savedTheme = await _preferences.getString(_themePreferenceKey);
    themePreference = ThemePreference.values.firstWhere(
      (preference) => preference.name == savedTheme,
      orElse: () => ThemePreference.system,
    );
    provisioning = await _credentialStore.readProvisioning();
    firstName = await _preferences.getString(_firstNameKey) ?? '';
    deviceUsername = await _preferences.getString(_deviceUsernameKey) ?? '';
    final trackingWanted =
        await _preferences.getBool(_trackingWantedKey) ?? true;

    if (provisioning == null || firstName.isEmpty || deviceUsername.isEmpty) {
      phase = AppPhase.onboarding;
      notifyListeners();
      return;
    }

    phase = AppPhase.ready;
    notifyListeners();
    try {
      await _tracker.configure(
        serverUrl: provisioning!.clientUrl,
        deviceId: deviceUsername,
      );
      if (trackingWanted) {
        await _tracker.start();
      }
      tracking = await _tracker.isTracking();
    } on Object catch (error) {
      lastError = 'Tracking needs attention. ${userFacingError(error)}';
    }
    await refreshTrackingHealth();

    try {
      await _connectManager(provisioning!);
    } on Object catch (error) {
      lastError = userFacingError(error);
      notifyListeners();
    }
  }

  Future<void> acceptQr(String encoded) {
    return _acceptProvisioning(ProvisioningConfig.fromQr(encoded));
  }

  Future<void> acceptManual({
    required String clientUrl,
    required String managerUrl,
    required String managerUsername,
    required String managerPassword,
  }) {
    return _acceptProvisioning(
      ProvisioningConfig.fromFields(
        clientUrl: clientUrl,
        managerUrl: managerUrl,
        managerUsername: managerUsername,
        managerPassword: managerPassword,
      ),
    );
  }

  Future<void> _acceptProvisioning(ProvisioningConfig config) async {
    busy = true;
    lastError = null;
    notifyListeners();
    TraccarApi? probe;
    try {
      probe = TraccarApi(config: config);
      await probe.login();
      pendingProvisioning = config;
    } finally {
      probe?.close();
      busy = false;
      notifyListeners();
    }
  }

  void clearPendingProvisioning() {
    pendingProvisioning = null;
    lastError = null;
    notifyListeners();
  }

  Future<void> completeProfile({
    required String firstName,
    required String username,
    bool replace = false,
  }) async {
    final config = pendingProvisioning;
    if (config == null) {
      throw const FormatException(
        'Scan the server QR code or enter the connection details first.',
      );
    }
    final cleanName = firstName.trim();
    final cleanUsername = username.trim();
    if (cleanName.isEmpty || cleanUsername.isEmpty) {
      throw const FormatException('First name and username are required.');
    }
    if (!RegExp(r'^[A-Za-z0-9][A-Za-z0-9._-]{0,63}$').hasMatch(cleanUsername) ||
        cleanUsername.contains('..')) {
      throw const FormatException(
        'Username may use letters, numbers, dots, dashes, and underscores, '
        'must start with a letter or number, and cannot contain two dots.',
      );
    }

    busy = true;
    lastError = null;
    notifyListeners();
    final api = TraccarApi(config: config);
    try {
      await api.login();
      final existing = await api.findDevice(cleanUsername);
      if (existing != null && !replace) {
        throw DeviceConflictException(existing);
      }
      if (existing == null) {
        await api.createDevice(name: cleanName, uniqueId: cleanUsername);
      } else {
        await api.updateDeviceName(existing, cleanName);
      }

      await _credentialStore.saveProvisioning(config);
      await Future.wait(<Future<void>>[
        _preferences.setString(_firstNameKey, cleanName),
        _preferences.setString(_deviceUsernameKey, cleanUsername),
        _preferences.setBool(_trackingWantedKey, true),
      ]);

      provisioning = config;
      this.firstName = cleanName;
      deviceUsername = cleanUsername;
      pendingProvisioning = null;
      _api?.close();
      _api = api;

      await _tracker.configure(
        serverUrl: config.clientUrl,
        deviceId: cleanUsername,
      );
      try {
        await _tracker.start();
        tracking = await _tracker.isTracking();
      } on Object catch (error) {
        tracking = false;
        lastError =
            'Account created, but tracking is off. ${userFacingError(error)}';
      }

      phase = AppPhase.ready;
      await refreshTrackingHealth();
      await refresh();
      _connectLive();
    } on DeviceConflictException {
      api.close();
      rethrow;
    } on Object {
      api.close();
      rethrow;
    } finally {
      busy = false;
      notifyListeners();
    }
  }

  Future<void> _connectManager(ProvisioningConfig config) async {
    _api?.close();
    final api = TraccarApi(config: config);
    await api.login();
    _api = api;
    await refresh();
    _connectLive();
  }

  Future<void> refresh() async {
    final api = _api;
    if (api == null) return;
    try {
      final cachedLocalPlaces = namedPlaces
          .where((place) => !place.serverBacked)
          .toList(growable: false);
      final results = await Future.wait<Object>([
        api.devices(),
        api.positions(),
        api.namedPlaces(),
        _loadMapTilerKey(api),
      ]);
      devices = results[0] as List<TraccarDevice>;
      positions = mergeLastKnownPositions({
        for (final entry in positions.entries)
          if (devices.any((device) => device.id == entry.key))
            entry.key: entry.value,
      }, results[1] as List<TraccarPosition>);
      _recordDrivingStatus(positions.values);
      var sharedPlaces = results[2] as List<NamedPlace>;
      for (final local in cachedLocalPlaces) {
        final alreadyExists = sharedPlaces.any(
          (shared) =>
              shared.name == local.name &&
              (shared.latitude - local.latitude).abs() < 0.000001 &&
              (shared.longitude - local.longitude).abs() < 0.000001,
        );
        if (!alreadyExists) {
          final migrated = await api.createNamedPlace(
            name: local.name,
            latitude: local.latitude,
            longitude: local.longitude,
            radiusMeters: local.radiusMeters,
            boundary: local.boundary,
          );
          sharedPlaces = <NamedPlace>[...sharedPlaces, migrated];
        }
      }
      namedPlaces = sharedPlaces;
      mapTilerApiKey = results[3] as String;
      await _namedPlaceStore.save(namedPlaces);
      unawaited(_loadDeviceImages(devices));
      try {
        await api.ensureNamedPlaceExitMonitoring(
          places: namedPlaces,
          devices: devices,
        );
        lastError = null;
      } on Object catch (error) {
        lastError =
            'Places loaded, but exit alerts could not be enabled. '
            '${userFacingError(error)}';
      }
    } on Object catch (error) {
      lastError = userFacingError(error);
    }
    notifyListeners();
  }

  Future<String> _loadMapTilerKey(TraccarApi api) async {
    try {
      return await api.mapTilerApiKey();
    } on Object {
      // Map configuration must not prevent devices and positions from loading
      // on older or restricted Traccar installations.
      return mapTilerApiKey;
    }
  }

  bool isDriving(TraccarPosition position) =>
      _drivingStatus.isDriving(position);

  void _recordDrivingStatus(Iterable<TraccarPosition> latest) {
    _drivingStatus.record(latest);
    _drivingExpiryTimer?.cancel();
    final delay = _drivingStatus.timeUntilNextExpiry;
    if (delay == null) return;
    _drivingExpiryTimer = Timer(delay + const Duration(milliseconds: 10), () {
      _recordDrivingStatus(const <TraccarPosition>[]);
      notifyListeners();
    });
  }

  /// The manager socket is useful only while the UI is visible. Background
  /// location uploads are owned by the native tracking SDK and continue after
  /// this socket is closed.
  void setAppForeground(bool visible) {
    if (_appForeground == visible) return;
    _appForeground = visible;
    if (!visible) {
      _disconnectLive();
      return;
    }

    _reconnectAttempts = 0;
    if (phase == AppPhase.ready && _api != null) {
      _connectLive();
    }
  }

  void _connectLive() {
    final api = _api;
    if (api == null || !_appForeground || phase != AppPhase.ready) return;
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    final previous = _liveSubscription;
    _liveSubscription = null;
    unawaited(previous?.cancel());
    final generation = ++_liveGeneration;
    _liveSubscription = api.liveUpdates().listen(
      (message) {
        if (generation != _liveGeneration || !_appForeground) return;
        _reconnectAttempts = 0;
        _handleLiveUpdate(message);
      },
      onError: (Object error) {
        _handleLiveDisconnect(generation, error: error);
      },
      onDone: () {
        _handleLiveDisconnect(generation);
      },
    );
    liveConnected = true;
    notifyListeners();
  }

  void _handleLiveDisconnect(int generation, {Object? error}) {
    if (generation != _liveGeneration) return;
    _liveSubscription = null;
    liveConnected = false;
    if (error != null) {
      lastError = 'Live updates disconnected. ${userFacingError(error)}';
    }
    notifyListeners();
    _scheduleReconnect();
  }

  void _disconnectLive() {
    _liveGeneration += 1;
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    _reconnectAttempts = 0;
    final subscription = _liveSubscription;
    _liveSubscription = null;
    unawaited(subscription?.cancel());
    if (liveConnected) {
      liveConnected = false;
      notifyListeners();
    }
  }

  void _handleLiveUpdate(Map<String, dynamic> message) {
    final devicePayloads = message['devices'] as List<dynamic>?;
    if (devicePayloads != null) {
      final byId = <int, TraccarDevice>{
        for (final item in devices) item.id: item,
      };
      for (final payload in devicePayloads) {
        final device = TraccarDevice.fromJson(
          Map<String, dynamic>.from(payload as Map),
        );
        byId[device.id] = device;
      }
      devices = byId.values.toList(growable: false);
      for (final payload in devicePayloads) {
        final device = TraccarDevice.fromJson(
          Map<String, dynamic>.from(payload as Map),
        );
        unawaited(_loadDeviceImage(device, force: true));
      }
    }
    final positionPayloads = message['positions'] as List<dynamic>?;
    if (positionPayloads != null) {
      final latest = <TraccarPosition>[];
      for (final payload in positionPayloads) {
        final position = TraccarPosition.fromJson(
          Map<String, dynamic>.from(payload as Map),
        );
        latest.add(position);
      }
      positions = mergeLastKnownPositions(positions, latest);
      _recordDrivingStatus(latest);
    }
    final eventPayloads = message['events'] as List<dynamic>?;
    if (eventPayloads != null) {
      for (final payload in eventPayloads.reversed) {
        final event = Map<String, dynamic>.from(payload as Map);
        if (event['type'] != 'geofenceExit') continue;
        final geofenceId = (event['geofenceId'] as num?)?.toInt();
        final deviceId = (event['deviceId'] as num?)?.toInt();
        NamedPlace? place;
        for (final item in namedPlaces) {
          if (item.serverId == geofenceId) {
            place = item;
            break;
          }
        }
        if (place == null || !place.notifyOnExit) continue;
        TraccarDevice? device;
        for (final item in devices) {
          if (item.id == deviceId) {
            device = item;
            break;
          }
        }
        exitAlert = '${device?.name ?? 'Someone'} left ${place.name}.';
        break;
      }
    }
    liveConnected = true;
    notifyListeners();
  }

  void dismissExitAlert() {
    if (exitAlert == null) return;
    exitAlert = null;
    notifyListeners();
  }

  void _scheduleReconnect() {
    if (!_appForeground || phase != AppPhase.ready || _api == null) return;
    _reconnectTimer?.cancel();
    final exponent = _reconnectAttempts > 6 ? 6 : _reconnectAttempts;
    final calculatedSeconds = 5 * (1 << exponent);
    final delay = Duration(
      seconds: calculatedSeconds > 300 ? 300 : calculatedSeconds,
    );
    _reconnectAttempts += 1;
    _reconnectTimer = Timer(delay, _connectLive);
  }

  Future<void> setTracking(bool enabled) async {
    busy = true;
    lastError = null;
    notifyListeners();
    try {
      if (enabled) {
        final config = provisioning;
        if (config == null) return;
        await _tracker.configure(
          serverUrl: config.clientUrl,
          deviceId: deviceUsername,
        );
        await _tracker.start();
      } else {
        await _tracker.stop();
      }
      tracking = await _tracker.isTracking();
      await _preferences.setBool(_trackingWantedKey, tracking);
      await refreshTrackingHealth();
    } on Object catch (error) {
      lastError = userFacingError(error);
    } finally {
      busy = false;
      notifyListeners();
    }
  }

  Future<void> refreshTrackingHealth() async {
    if (phase != AppPhase.ready) return;
    try {
      trackingHealth = await _tracker.trackingHealth();
    } on Object {
      trackingHealth = const TrackingHealth.unchecked();
    }
    notifyListeners();
  }

  Future<void> openLocationSettings() => _tracker.openLocationSettings();

  Future<void> openBatterySettings() => _tracker.openBatterySettings();

  Future<bool> sendPositionNow() async {
    busy = true;
    lastError = null;
    notifyListeners();
    try {
      final sent = await _tracker.sendNow();
      if (!sent) lastError = 'The SDK could not upload a position.';
      return sent;
    } on Object catch (error) {
      lastError = userFacingError(error);
      return false;
    } finally {
      busy = false;
      notifyListeners();
    }
  }

  Future<String> arrivalSummary(TraccarPosition position) async {
    final api = _api;
    final end = position.fixTime;
    if (api == null || end == null) return 'Here since: unknown';
    final place = NamedPlaceStore.nearest(
      namedPlaces,
      position.latitude,
      position.longitude,
    );
    if (place == null && position.isMoving) return 'Currently moving';
    try {
      final history = await api.positionHistory(
        position.deviceId,
        end.subtract(const Duration(days: 7)),
        end,
      );
      final fixes =
          history.where((fix) => fix.valid && fix.fixTime != null).toList()
            ..sort((a, b) => a.fixTime!.compareTo(b.fixTime!));
      DateTime? arrival;
      var foundOutside = false;
      for (final fix in fixes.reversed) {
        final inside = place != null
            ? NamedPlaceStore.nearest([place], fix.latitude, fix.longitude) !=
                  null
            : const Distance().as(
                    LengthUnit.Meter,
                    LatLng(position.latitude, position.longitude),
                    LatLng(fix.latitude, fix.longitude),
                  ) <=
                  50;
        if (!inside) {
          foundOutside = true;
          break;
        }
        arrival = fix.fixTime;
      }
      if (arrival == null) return 'Here since: unknown';
      final age = DateTime.now().difference(arrival);
      final duration = age.inDays > 0
          ? '${age.inDays}d'
          : age.inHours > 0
          ? '${age.inHours}h'
          : age.inMinutes > 0
          ? '${age.inMinutes}m'
          : 'less than 1m';
      return 'Here since ${foundOutside ? "" : "at least "}$duration ago';
    } on Object {
      return 'Here since: unknown';
    }
  }

  Future<String> reverseGeocode(TraccarPosition position) async {
    final place = NamedPlaceStore.nearest(
      namedPlaces,
      position.latitude,
      position.longitude,
    );
    if (place != null) return place.name;
    if (position.address?.trim().isNotEmpty ?? false) return position.address!;
    final api = _api;
    if (api == null) throw const TraccarApiException('Manager is offline.');
    // Provider credentials and provider selection stay on the server. The
    // client only uses Traccar's authenticated geocode endpoint.
    return api.reverseGeocode(position.latitude, position.longitude);
  }

  bool satelliteAtZoom(double zoom) =>
      satelliteAlways || (satelliteAutoAtStreetZoom && zoom >= satelliteZoom);

  Future<void> saveMapAppearance({
    bool? satelliteAutoAtStreetZoom,
    bool? darkMap,
    double? satelliteZoom,
    bool? satelliteAlways,
  }) {
    this.satelliteAutoAtStreetZoom =
        satelliteAutoAtStreetZoom ?? this.satelliteAutoAtStreetZoom;
    this.darkMap = darkMap ?? this.darkMap;
    this.satelliteZoom = (satelliteZoom ?? this.satelliteZoom).clamp(2, 21);
    this.satelliteAlways = satelliteAlways ?? this.satelliteAlways;
    notifyListeners();
    final auto = this.satelliteAutoAtStreetZoom;
    final dark = this.darkMap;
    final zoom = this.satelliteZoom;
    final always = this.satelliteAlways;
    // Serialize writes so rapid changes cannot restore an older preference.
    final save = _appearanceSave.catchError((Object _) {}).then((_) async {
      await _preferences.setBool(_satelliteAutoKey, auto);
      await _preferences.setBool(_darkMapKey, dark);
      await _preferences.setDouble(_satelliteZoomKey, zoom);
      await _preferences.setBool(_satelliteAlwaysKey, always);
    });
    _appearanceSave = save;
    return save;
  }

  Future<void> setThemePreference(ThemePreference preference) async {
    themePreference = preference;
    notifyListeners();
    await _preferences.setString(_themePreferenceKey, preference.name);
  }

  String? friendlyPlaceFor(TraccarPosition position) {
    return NamedPlaceStore.nearest(
      namedPlaces,
      position.latitude,
      position.longitude,
    )?.name;
  }

  Future<void> addNamedPlace({
    required String name,
    required double latitude,
    required double longitude,
    double radiusMeters = 150,
    List<LatLng> boundary = const <LatLng>[],
  }) async {
    final api = _api;
    final cleanName = name.trim();
    if (api == null) {
      throw const TraccarApiException(
        'Connect to the manager server before saving a shared place.',
      );
    }
    if (cleanName.isEmpty) {
      throw const FormatException('Enter a place name.');
    }
    if (boundary.isNotEmpty && boundary.length < 3) {
      throw const FormatException('Draw at least 3 corners for the place.');
    }
    if (boundary.isEmpty &&
        (!radiusMeters.isFinite || radiusMeters < 10 || radiusMeters > 10000)) {
      throw const FormatException(
        'Radius must be between 10 and 10,000 meters.',
      );
    }
    try {
      final place = await api.createNamedPlace(
        name: cleanName,
        latitude: latitude,
        longitude: longitude,
        radiusMeters: radiusMeters,
        boundary: boundary,
      );
      namedPlaces = <NamedPlace>[...namedPlaces, place];
      await _namedPlaceStore.save(namedPlaces);
      try {
        await api.ensureNamedPlaceExitMonitoring(
          places: namedPlaces,
          devices: devices,
        );
        lastError = null;
      } on Object catch (error) {
        lastError =
            '${place.name} was saved, but exit alerts could not be enabled. '
            '${userFacingError(error)}';
      }
      notifyListeners();
    } on Object catch (error) {
      lastError = userFacingError(error);
      notifyListeners();
      rethrow;
    }
  }

  Future<void> deleteNamedPlace(String id) async {
    final api = _api;
    final serverId = int.tryParse(id);
    if (api == null || serverId == null) {
      throw const TraccarApiException(
        'Connect to the manager server before deleting a shared place.',
      );
    }
    try {
      await api.deleteNamedPlace(serverId);
      namedPlaces = namedPlaces.where((place) => place.id != id).toList();
      await _namedPlaceStore.save(namedPlaces);
      lastError = null;
      notifyListeners();
    } on Object catch (error) {
      lastError = userFacingError(error);
      notifyListeners();
      rethrow;
    }
  }

  Future<void> updateProfilePicture(Uint8List bytes, String contentType) async {
    final api = _api;
    final device = ownDevice;
    if (api == null || device == null) {
      throw const TraccarApiException(
        'Your Traccar device is not available. Refresh and try again.',
      );
    }
    busy = true;
    lastError = null;
    notifyListeners();
    try {
      final updated = await api.uploadDeviceImage(device, bytes, contentType);
      devices = devices
          .map((item) => item.id == updated.id ? updated : item)
          .toList(growable: false);
      deviceImages = <int, Uint8List>{...deviceImages, updated.id: bytes};
    } on Object catch (error) {
      lastError = userFacingError(error);
      rethrow;
    } finally {
      busy = false;
      notifyListeners();
    }
  }

  Future<void> _loadDeviceImages(List<TraccarDevice> currentDevices) async {
    await Future.wait(currentDevices.map(_loadDeviceImage));
  }

  Future<void> _loadDeviceImage(
    TraccarDevice device, {
    bool force = false,
  }) async {
    if (!force && deviceImages.containsKey(device.id)) return;
    final api = _api;
    if (api == null || device.imageName == null) return;
    try {
      final bytes = await api.deviceImage(device);
      if (bytes == null) return;
      deviceImages = <int, Uint8List>{...deviceImages, device.id: bytes};
      notifyListeners();
    } on Object {
      // A missing or inaccessible picture should fall back to initials.
    }
  }

  Future<void> resetApp() async {
    // Leave the authenticated UI immediately. Native tracker shutdown and
    // storage cleanup can take time, and must not trap the user on Settings.
    final subscription = _liveSubscription;
    _liveSubscription = null;
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    _drivingExpiryTimer?.cancel();
    _drivingExpiryTimer = null;
    _drivingStatus.clear();
    _appForeground = false;
    _liveGeneration += 1;
    _reconnectAttempts = 0;
    _api?.close();
    _api = null;
    provisioning = null;
    pendingProvisioning = null;
    firstName = '';
    deviceUsername = '';
    tracking = false;
    liveConnected = false;
    devices = const [];
    positions = const {};
    deviceImages = const {};
    namedPlaces = const [];
    satelliteZoom = 19;
    satelliteAlways = false;
    darkMap = false;
    satelliteAutoAtStreetZoom = true;
    mapTilerApiKey = '';
    themePreference = ThemePreference.system;
    lastError = null;
    exitAlert = null;
    trackingHealth = const TrackingHealth.unchecked();
    phase = AppPhase.onboarding;
    notifyListeners();

    Object? resetError;
    Future<void> attempt(Future<void> Function() action) async {
      try {
        await action();
      } on Object catch (error) {
        resetError ??= error;
      }
    }

    await attempt(() => _tracker.stop().timeout(const Duration(seconds: 15)));
    await attempt(() async {
      await subscription?.cancel();
    });
    await attempt(_credentialStore.clearProvisioning);
    await attempt(() => _appearanceSave);
    await attempt(
      () => Future.wait(<Future<void>>[
        _preferences.remove(_firstNameKey),
        _preferences.remove(_deviceUsernameKey),
        _preferences.remove(_trackingWantedKey),
        _preferences.remove(_satelliteAutoKey),
        _preferences.remove(_darkMapKey),
        _preferences.remove(_satelliteZoomKey),
        _preferences.remove(_satelliteAlwaysKey),
        _preferences.remove(_themePreferenceKey),
        _namedPlaceStore.save(const []),
      ]),
    );
    if (resetError != null) {
      lastError =
          'Some local data could not be cleared. Please try resetting again.';
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _liveGeneration += 1;
    _reconnectTimer?.cancel();
    unawaited(_liveSubscription?.cancel());
    _api?.close();
    _drivingExpiryTimer?.cancel();
    super.dispose();
  }
}
