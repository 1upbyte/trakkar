import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'models/named_place.dart';
import 'models/provisioning_config.dart';
import 'models/traccar_device.dart';
import 'models/traccar_position.dart';
import 'services/credential_store.dart';
import 'services/named_place_store.dart';
import 'services/reverse_geocoder.dart';
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
    ReverseGeocoder? reverseGeocoder,
    TrackerService? trackerService,
    SharedPreferencesAsync? preferences,
  }) : _credentialStore = credentialStore ?? CredentialStore(),
       _namedPlaceStore = namedPlaceStore ?? NamedPlaceStore(),
       _preferences = preferences ?? SharedPreferencesAsync(),
       _tracker = trackerService ?? TrackerService(),
       _reverseGeocoder =
           reverseGeocoder ??
           ReverseGeocoder(credentialStore ?? CredentialStore());

  static const _firstNameKey = 'profile.firstName';
  static const _deviceUsernameKey = 'profile.deviceUsername';
  static const _trackingWantedKey = 'tracking.wanted';

  final CredentialStore _credentialStore;
  final NamedPlaceStore _namedPlaceStore;
  final SharedPreferencesAsync _preferences;
  final TrackerService _tracker;
  final ReverseGeocoder _reverseGeocoder;

  AppPhase phase = AppPhase.loading;
  ProvisioningConfig? pendingProvisioning;
  ProvisioningConfig? provisioning;
  TraccarApi? _api;
  StreamSubscription<Map<String, dynamic>>? _liveSubscription;
  Timer? _reconnectTimer;

  String firstName = '';
  String deviceUsername = '';
  bool tracking = false;
  bool liveConnected = false;
  bool busy = false;
  String? lastError;

  List<TraccarDevice> devices = const [];
  Map<int, TraccarPosition> positions = const {};
  List<NamedPlace> namedPlaces = const [];
  GeocodingSettings geocodingSettings = const GeocodingSettings();

  Future<void> bootstrap() async {
    namedPlaces = await _namedPlaceStore.load();
    geocodingSettings = await _reverseGeocoder.loadSettings();
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
      final results = await Future.wait<Object>([
        api.devices(),
        api.positions(),
      ]);
      devices = results[0] as List<TraccarDevice>;
      positions = <int, TraccarPosition>{
        for (final position in results[1] as List<TraccarPosition>)
          position.deviceId: position,
      };
      lastError = null;
    } on Object catch (error) {
      lastError = userFacingError(error);
    }
    notifyListeners();
  }

  void _connectLive() {
    final api = _api;
    if (api == null) return;
    _reconnectTimer?.cancel();
    unawaited(_liveSubscription?.cancel());
    _liveSubscription = api.liveUpdates().listen(
      _handleLiveUpdate,
      onError: (Object error) {
        liveConnected = false;
        lastError = 'Live updates disconnected. ${userFacingError(error)}';
        notifyListeners();
        _scheduleReconnect();
      },
      onDone: () {
        liveConnected = false;
        notifyListeners();
        _scheduleReconnect();
      },
    );
    liveConnected = true;
    notifyListeners();
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
    }
    final positionPayloads = message['positions'] as List<dynamic>?;
    if (positionPayloads != null) {
      final updated = Map<int, TraccarPosition>.from(positions);
      for (final payload in positionPayloads) {
        final position = TraccarPosition.fromJson(
          Map<String, dynamic>.from(payload as Map),
        );
        updated[position.deviceId] = position;
      }
      positions = updated;
    }
    liveConnected = true;
    notifyListeners();
  }

  void _scheduleReconnect() {
    if (phase != AppPhase.ready || _api == null) return;
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(const Duration(seconds: 5), _connectLive);
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
    } on Object catch (error) {
      lastError = userFacingError(error);
    } finally {
      busy = false;
      notifyListeners();
    }
  }

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
    return _reverseGeocoder.lookup(
      latitude: position.latitude,
      longitude: position.longitude,
      settings: geocodingSettings,
      api: api,
    );
  }

  Future<void> saveGeocodingSettings(GeocodingSettings settings) async {
    await _reverseGeocoder.saveSettings(settings);
    geocodingSettings = settings;
    notifyListeners();
  }

  Future<void> addNamedPlace({
    required String name,
    required double latitude,
    required double longitude,
    double radiusMeters = 150,
  }) async {
    final place = NamedPlace(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      name: name.trim(),
      latitude: latitude,
      longitude: longitude,
      radiusMeters: radiusMeters,
    );
    namedPlaces = <NamedPlace>[...namedPlaces, place];
    await _namedPlaceStore.save(namedPlaces);
    notifyListeners();
  }

  Future<void> deleteNamedPlace(String id) async {
    namedPlaces = namedPlaces.where((place) => place.id != id).toList();
    await _namedPlaceStore.save(namedPlaces);
    notifyListeners();
  }

  Future<void> resetApp() async {
    await _tracker.stop();
    await _credentialStore.clearProvisioning();
    await Future.wait(<Future<void>>[
      _preferences.remove(_firstNameKey),
      _preferences.remove(_deviceUsernameKey),
      _preferences.remove(_trackingWantedKey),
      _namedPlaceStore.save(const []),
    ]);
    await _liveSubscription?.cancel();
    _reconnectTimer?.cancel();
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
    namedPlaces = const [];
    lastError = null;
    phase = AppPhase.onboarding;
    notifyListeners();
  }

  @override
  void dispose() {
    _reconnectTimer?.cancel();
    unawaited(_liveSubscription?.cancel());
    _api?.close();
    _reverseGeocoder.close();
    super.dispose();
  }
}
