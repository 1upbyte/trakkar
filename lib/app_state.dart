import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'models/map_api_keys.dart';
import 'models/map_style_option.dart';
import 'models/named_place.dart';
import 'models/provisioning_config.dart';
import 'models/theme_preference.dart';
import 'models/traccar_device.dart';
import 'models/traccar_position.dart';
import 'models/traccar_user.dart';
import 'services/credential_store.dart';
import 'services/live_watch.dart';
import 'services/map_sdk_service.dart';
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
    MapSdkService? mapSdkService,
    SharedPreferencesAsync? preferences,
  }) : _credentialStore = credentialStore ?? CredentialStore(),
       _namedPlaceStore = namedPlaceStore ?? NamedPlaceStore(),
       _preferences = preferences ?? SharedPreferencesAsync(),
       _tracker = trackerService ?? TrackerService(),
       _mapSdk = mapSdkService ?? MapSdkService() {
    _liveWatch = LiveWatchCoordinator(
      publishWatch: _publishWatch,
      fetchDevices: _fetchDevicesForWatch,
      sendPosition: _sendWatchedPosition,
      ownUniqueId: () => deviceUsername,
      onDevices: _applyPolledDevices,
    );
  }

  static const _firstNameKey = 'profile.firstName';
  static const _deviceUsernameKey = 'profile.deviceUsername';
  static const _trackingWantedKey = 'tracking.wanted';
  static const _mapStyleKey = 'map.style';
  static const _satelliteWhenZoomedKey = 'map.satelliteWhenZoomed';
  static const _themePreferenceKey = 'appearance.theme';

  // Preferences written by earlier builds that configured reverse geocoding
  // on the phone. Address lookup is server-side only now.
  static const _legacyPreferenceKeys = <String>[
    'geocoding.provider',
    'geocoding.customUrlTemplate',
  ];

  final CredentialStore _credentialStore;
  final NamedPlaceStore _namedPlaceStore;
  final SharedPreferencesAsync _preferences;
  final TrackerService _tracker;
  final MapSdkService _mapSdk;
  late final LiveWatchCoordinator _liveWatch;

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
  TrackingHealth trackingHealth = const TrackingHealth.unchecked();

  List<TraccarDevice> devices = const [];
  Map<int, TraccarPosition> positions = const {};
  Map<int, Uint8List> deviceImages = const {};
  List<NamedPlace> namedPlaces = const [];
  TraccarUser? managerUser;
  MapStyleOption mapStyle = MapStyleOption.positron;
  MapApiKeys mapApiKeys = const MapApiKeys();
  bool satelliteWhenZoomed = true;
  bool googleMapsKeyApplied = false;
  ThemePreference themePreference = ThemePreference.system;

  TraccarDevice? get ownDevice {
    for (final device in devices) {
      if (device.uniqueId == deviceUsername) return device;
    }
    return null;
  }

  /// People whose phone currently has the map open.
  List<String> get watchers => _liveWatch.watchers;

  /// True while this phone is advertising an open map to everyone else.
  bool get mapVisible => _liveWatch.isWatching;

  bool get googleMapsReady =>
      mapApiKeys.googleMaps.isNotEmpty && googleMapsKeyApplied;

  Future<void> bootstrap() async {
    namedPlaces = await _namedPlaceStore.load();
    final savedMapStyle = await _preferences.getString(_mapStyleKey);
    mapStyle = MapStyleOption.values.firstWhere(
      (style) => style.name == savedMapStyle,
      orElse: () => MapStyleOption.positron,
    );
    satelliteWhenZoomed =
        await _preferences.getBool(_satelliteWhenZoomedKey) ?? true;
    mapApiKeys = await _credentialStore.readMapKeys();
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
    for (final key in _legacyPreferenceKeys) {
      unawaited(_preferences.remove(key));
    }

    if (provisioning == null || firstName.isEmpty || deviceUsername.isEmpty) {
      phase = AppPhase.onboarding;
      notifyListeners();
      return;
    }

    phase = AppPhase.ready;
    notifyListeners();
    unawaited(_applyGoogleMapsKey());
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
      await _adoptSharedSettings(api.user);

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
      _syncWatchPolling();
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
    await _adoptSharedSettings(api.user);
    await refresh();
    _connectLive();
    _syncWatchPolling();
  }

  /// Applies settings stored on the manager user, such as map SDK keys, and
  /// refreshes the local cache so the next launch starts with them.
  Future<void> _adoptSharedSettings(TraccarUser? user) async {
    var current = user;
    if (current == null) {
      try {
        current = await _api?.session();
      } on Object {
        current = null;
      }
    }
    if (current == null) return;
    managerUser = current;
    final serverKeys = MapApiKeys.fromAttributes(current.attributes);
    if (serverKeys.isEmpty) return;
    final merged = mapApiKeys.mergedWith(serverKeys);
    if (merged != mapApiKeys) {
      mapApiKeys = merged;
      await _credentialStore.saveMapKeys(merged);
      notifyListeners();
    }
    await _applyGoogleMapsKey();
  }

  Future<void> _applyGoogleMapsKey() async {
    if (mapApiKeys.googleMaps.isEmpty) {
      googleMapsKeyApplied = false;
      notifyListeners();
      return;
    }
    try {
      googleMapsKeyApplied = await _mapSdk.applyGoogleMapsKey(
        mapApiKeys.googleMaps,
      );
    } on Object catch (error) {
      googleMapsKeyApplied = false;
      debugPrint('Google Maps key could not be applied: $error');
    }
    notifyListeners();
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
      ]);
      devices = results[0] as List<TraccarDevice>;
      positions = <int, TraccarPosition>{
        for (final position in results[1] as List<TraccarPosition>)
          position.deviceId: position,
      };
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
          );
          sharedPlaces = <NamedPlace>[...sharedPlaces, migrated];
        }
      }
      namedPlaces = sharedPlaces;
      await _namedPlaceStore.save(namedPlaces);
      unawaited(_loadDeviceImages(devices));
      unawaited(_liveWatch.observeDevices(devices));
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
      for (final payload in devicePayloads) {
        final device = TraccarDevice.fromJson(
          Map<String, dynamic>.from(payload as Map),
        );
        unawaited(_loadDeviceImage(device, force: true));
      }
      unawaited(_liveWatch.observeDevices(devices));
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

  // ---------------------------------------------------------------------
  // Live watch: keep positions fresh while someone has the map open.
  // ---------------------------------------------------------------------

  /// Called by the home screen whenever the map tab is shown or hidden, and
  /// when the app moves between foreground and background.
  void setMapVisible(bool visible) {
    _mapVisibleWanted = visible;
    _applyMapVisibility();
  }

  bool _mapVisibleWanted = false;

  /// Publishes the wanted visibility once a manager session exists. The home
  /// screen can report the map as visible before sign-in completes.
  void _applyMapVisibility() {
    final canWatch = phase == AppPhase.ready && _api != null;
    final target = _mapVisibleWanted && canWatch;
    if (target == _liveWatch.isWatching) return;
    unawaited(
      _liveWatch.setWatching(target).then((_) {
        if (phase != AppPhase.loading) notifyListeners();
      }),
    );
  }

  void _syncWatchPolling() {
    if (phase == AppPhase.ready && _api != null && tracking) {
      _liveWatch.startPolling();
    } else {
      _liveWatch.stopPolling();
    }
    _applyMapVisibility();
  }

  Future<void> _publishWatch(DateTime? until) async {
    final api = _api;
    final device = ownDevice;
    if (api == null || device == null) return;
    final attributes = device.attributes;
    final current = device.watchUntil;
    if (until == null) {
      if (current == null) return;
      attributes.remove(TraccarDevice.watchUntilAttribute);
    } else {
      attributes[TraccarDevice.watchUntilAttribute] =
          until.toUtc().millisecondsSinceEpoch;
    }
    final updated = await api.updateDeviceAttributes(
      device,
      attributes,
      action: 'Sharing map activity',
    );
    devices = devices
        .map((item) => item.id == updated.id ? updated : item)
        .toList(growable: false);
  }

  Future<List<TraccarDevice>> _fetchDevicesForWatch() async {
    final api = _api;
    if (api == null) throw const TraccarApiException('Manager is offline.');
    return api.devices();
  }

  Future<bool> _sendWatchedPosition() async {
    if (!tracking) return false;
    return _tracker.sendNow();
  }

  void _applyPolledDevices(List<TraccarDevice> polled) {
    final previousWatchers = watchers;
    devices = polled;
    unawaited(_loadDeviceImages(polled));
    // Only repaint when something visible changed. The watch attribute
    // itself churns every heartbeat.
    if (!listEquals(previousWatchers, _liveWatch.watchers)) {
      notifyListeners();
    }
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
      _syncWatchPolling();
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

  /// Resolves a position to a friendly place, the address Traccar attached,
  /// or the server's own reverse geocoder, in that order. The phone never
  /// talks to a third-party geocoding service.
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
    final address = await api.reverseGeocode(
      position.latitude,
      position.longitude,
    );
    return address.isEmpty ? 'No address found' : address;
  }

  /// Saves the base map style and the shared SDK keys. Keys are written to
  /// the manager user on the server so every phone on the account receives
  /// them; the local cache is updated only after the server accepts them.
  Future<void> saveMapAppearance({
    required MapStyleOption style,
    required MapApiKeys keys,
  }) async {
    if (style.isGoogle && keys.googleMaps.isEmpty) {
      throw const FormatException(
        'Google Maps needs a Maps SDK API key. Add one below.',
      );
    }
    if (style.isSatellite && keys.mapTiler.isEmpty) {
      throw const FormatException(
        'MapTiler satellite view requires a MapTiler API key.',
      );
    }
    if (keys != mapApiKeys) {
      await _saveSharedMapKeys(keys);
    }
    await _preferences.setString(_mapStyleKey, style.name);
    mapStyle = style;
    notifyListeners();
    await _applyGoogleMapsKey();
  }

  Future<void> _saveSharedMapKeys(MapApiKeys keys) async {
    final api = _api;
    var user = managerUser ?? api?.user;
    if (api != null && user == null) {
      try {
        user = await api.session();
      } on Object {
        user = null;
      }
    }
    if (api == null || user == null) {
      throw const TraccarApiException(
        'Connect to the manager server before changing shared map keys.',
      );
    }
    managerUser = await api.updateUserAttributes(
      user,
      keys.applyTo(user.attributes),
    );
    mapApiKeys = keys;
    await _credentialStore.saveMapKeys(keys);
  }

  Future<void> setSatelliteWhenZoomed(bool enabled) async {
    satelliteWhenZoomed = enabled;
    notifyListeners();
    await _preferences.setBool(_satelliteWhenZoomedKey, enabled);
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
    if (!radiusMeters.isFinite || radiusMeters < 10 || radiusMeters > 10000) {
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
      );
      namedPlaces = <NamedPlace>[...namedPlaces, place];
      await _namedPlaceStore.save(namedPlaces);
      lastError = null;
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
    _liveWatch.stopPolling();
    _mapVisibleWanted = false;
    final api = _api;
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
    managerUser = null;
    mapStyle = MapStyleOption.positron;
    mapApiKeys = const MapApiKeys();
    satelliteWhenZoomed = true;
    googleMapsKeyApplied = false;
    themePreference = ThemePreference.system;
    lastError = null;
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

    await attempt(() => _liveWatch.setWatching(false));
    api?.close();
    await attempt(() => _tracker.stop().timeout(const Duration(seconds: 15)));
    await attempt(() async {
      await subscription?.cancel();
    });
    await attempt(_credentialStore.clearProvisioning);
    await attempt(
      () => Future.wait(<Future<void>>[
        _preferences.remove(_firstNameKey),
        _preferences.remove(_deviceUsernameKey),
        _preferences.remove(_trackingWantedKey),
        _preferences.remove(_mapStyleKey),
        _preferences.remove(_satelliteWhenZoomedKey),
        _preferences.remove(_themePreferenceKey),
        for (final key in _legacyPreferenceKeys) _preferences.remove(key),
        _namedPlaceStore.save(const []),
      ]),
    );
    await attempt(_credentialStore.clearMapKeys);

    if (resetError != null) {
      lastError =
          'Some local data could not be cleared. Please try resetting again.';
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _reconnectTimer?.cancel();
    unawaited(_liveSubscription?.cancel());
    unawaited(_liveWatch.dispose());
    _api?.close();
    super.dispose();
  }
}
