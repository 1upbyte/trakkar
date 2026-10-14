import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';

import '../features/map/map_screen.dart';
import '../features/people/people_list_state.dart';
import '../features/people/people_screen.dart';
import '../features/places/places_list_state.dart';
import '../features/places/places_screen.dart';
import '../features/settings/settings_screen.dart';
import '../features/settings/settings_state.dart';
import '../models/map_appearance_preference.dart';
import '../models/place_creation_draft.dart';
import '../models/person.dart';
import '../models/server_details.dart';
import '../models/saved_place.dart';
import '../app/app_theme.dart';
import '../services/auth/secure_session_store.dart';
import '../services/auth/setup_controller.dart';
import '../services/map/map_preferences.dart';
import '../services/places/geofence_repository.dart';
import '../services/settings/app_reset_service.dart';
import '../services/settings/preferences_repository.dart';
import '../services/settings/profile_image_repository.dart';
import '../services/settings/settings_repository.dart';
import '../services/traccar_data_repository.dart';
import '../services/tracking/traccar_tracking_service.dart';
import '../services/tracking/live_tracking_service.dart';
import '../widgets/server_connection_banner.dart';

class AppShell extends StatefulWidget {
  const AppShell({
    required this.controller,
    this.themeController,
    this.preferences,
    this.locationAccessCheck,
    this.onRequestLocationAccess,
    this.mapStyleLoader,
    super.key,
  });

  final SetupController controller;
  final AppThemeController? themeController;
  final PreferencesRepository? preferences;
  final Future<bool> Function()? locationAccessCheck;
  final Future<void> Function()? onRequestLocationAccess;
  final MapStyleLoader? mapStyleLoader;

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> with WidgetsBindingObserver {
  final _tracking = TraccarTrackingService();
  LiveTrackingService? _liveTracking;
  bool _appResumed = true;
  final _sessionStore = SecureSessionStore();
  final _mapPreferences = MapPreferences();
  late final PreferencesRepository _preferences =
      widget.preferences ?? PreferencesRepository();
  late final AppThemeController _themeController =
      widget.themeController ?? AppThemeController(preferences: _preferences);
  bool _locationReady = false;
  bool _trackingStarted = false;
  bool _trackingConfigured = false;
  bool _serverConnectionFailed = false;
  bool _satelliteUnavailable = false;
  int _selectedTab = 0;
  double _satelliteThreshold = 19;
  TraccarDataRepository? _mapRepository;
  GeofenceRepository? _geofenceRepository;
  SettingsApiClient? _settingsApi;
  SettingsState? _settingsState;
  String? _avatarImageRef;
  Future<Uint8List>? _avatarImage;
  ServerDetails _serverDetails = const ServerDetails(
    clientUrl: null,
    managerUrl: null,
    accountName: null,
  );
  final _mapScreenKey = GlobalKey<MapScreenState>();
  PeopleListState _peopleState = PeopleListState(
    people: const [],
    isLoading: true,
  );
  List<SavedPlace> _places = const [];
  PlacesListState _placesState = PlacesListState(
    places: const [],
    isLoading: true,
  );

  static const _tabNames = ['Map', 'People', 'Places', 'Settings'];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _appResumed =
        WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed;
    _refreshLocationPermission();
    unawaited(_loadMapPreference());
    if (widget.controller.hasAuthenticatedSession) {
      unawaited(_configureTracking());
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _appResumed = state == AppLifecycleState.resumed;
    _updateLiveTrackingVisibility();
    if (_appResumed) _refreshLocationPermission();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _liveTracking?.dispose();
    unawaited(_mapRepository?.close());
    _settingsApi?.close();
    _settingsState?.removeListener(_onSettingsStateChanged);
    _settingsState?.dispose();
    super.dispose();
  }

  Future<void> _configureTracking() async {
    try {
      final stored = await _sessionStore.read();
      if (stored != null) {
        _mapRepository ??= TraccarDataRepository(
          managerUrl: stored.details.managerUrl,
          sessionCookie: stored.cookie,
        );
        _geofenceRepository ??= TraccarGeofenceRepository(_mapRepository!);
        _serverDetails = ServerDetails.redacted(
          clientUrl: stored.details.clientUrl,
          managerUrl: stored.details.managerUrl,
          accountName: stored.details.username,
        );
        _settingsApi ??= SettingsApiClient(
          managerUrl: stored.details.managerUrl,
          sessionCookie: stored.cookie,
        );
        if (_settingsState == null) {
          _settingsState = SettingsState(
            profileRepository: TraccarProfileRepository(_settingsApi!),
            imageRepository: TraccarProfileImageRepository(_settingsApi!),
            preferences: _preferences,
            deviceUniqueId: await _tracking.deviceUniqueId(),
            serverDetails: _serverDetails,
          );
          _settingsState!.addListener(_onSettingsStateChanged);
          unawaited(_settingsState!.load());
        }
        if (mounted) setState(() {});
        await _tracking.configure(stored.details);
        _trackingConfigured = true;
        await _maybeStartTracking();
        if (!mounted) return;
        _liveTracking ??= LiveTrackingService(
          sessionCookie: stored.cookie,
          uniqueId: await _tracking.deviceUniqueId(),
        );
        _liveTracking!.setDevices(
          _peopleState.people.map((person) => person.deviceId),
        );
        _updateLiveTrackingVisibility();
      }
    } on Object {
      if (mounted) setState(() => _serverConnectionFailed = true);
    }
  }

  void _onSettingsStateChanged() {
    final reference = _settingsState?.profile?.profileImageRef;
    if (reference != _avatarImageRef) {
      _avatarImageRef = reference;
      final repository = _mapRepository;
      _avatarImage = reference == null || repository == null
          ? null
          : repository.loadProfileImage(reference);
    }
    if (mounted) setState(() {});
  }

  Future<void> _loadMapPreference() async {
    final preference = await _mapPreferences.read();
    if (mounted) {
      setState(() => _satelliteThreshold = preference.satelliteThresholdZoom);
    }
  }

  Future<void> _saveMapPreference(double value) async {
    if (!mounted) return;
    setState(() => _satelliteThreshold = value);
    final preference = MapAppearancePreference(satelliteThresholdZoom: value);
    await _mapPreferences.save(preference);
    await _settingsState?.saveMapAppearance(preference);
  }

  Future<void> _resetApp() async {
    await AppResetService(
      sessionStore: _sessionStore,
      preferences: _preferences,
      tracking: _tracking,
    ).reset();
    await _liveTracking?.unregister();
    await _themeController.reset();
    widget.controller.resetToFirstRun();
  }

  Future<void> _refreshLocationPermission() async {
    try {
      final ready =
          await (widget.locationAccessCheck?.call() ??
              _hasRequiredLocationAccess());
      if (!mounted) return;
      setState(() => _locationReady = ready);
      await _maybeStartTracking();
    } on Object {
      if (mounted) setState(() => _locationReady = false);
    }
  }

  Future<bool> _hasRequiredLocationAccess() async {
    final permission = await Geolocator.checkPermission();
    final accuracy = await Geolocator.getLocationAccuracy();
    return permission == LocationPermission.always &&
        accuracy == LocationAccuracyStatus.precise;
  }

  Future<void> _maybeStartTracking() async {
    if (_locationReady &&
        _trackingConfigured &&
        !_trackingStarted &&
        widget.controller.hasAuthenticatedSession) {
      try {
        _trackingStarted = true;
        final connected = await _tracking.requestPosition();
        if (!connected) {
          _trackingStarted = false;
          if (mounted) setState(() => _serverConnectionFailed = true);
          return;
        }
        await _tracking.start();
        _updateLiveTrackingVisibility();
        if (mounted) setState(() => _serverConnectionFailed = false);
      } on Object {
        _trackingStarted = false;
        if (mounted) setState(() => _serverConnectionFailed = true);
      }
    }
  }

  void _updateLiveTrackingVisibility() {
    _liveTracking?.setVisible(_appResumed && _selectedTab == 0);
  }

  Future<void> _retryServerConnection() async {
    if (widget.controller.hasAuthenticatedSession) {
      await _configureTracking();
      await _maybeStartTracking();
    } else {
      await widget.controller.retry();
    }
  }

  Future<void> _requestLocation() async {
    final current = await Permission.locationWhenInUse.request();
    if (current.isGranted) await Permission.locationAlways.request();
    if (await Permission.location.isPermanentlyDenied ||
        await Permission.locationAlways.isPermanentlyDenied) {
      await openAppSettings();
    }
    if (await Geolocator.getLocationAccuracy() ==
        LocationAccuracyStatus.reduced) {
      await Geolocator.requestTemporaryFullAccuracy(purposeKey: 'location');
    }
  }

  Future<void> _requestLocationAccess() async {
    final customRequest = widget.onRequestLocationAccess;
    if (customRequest == null) {
      await _requestLocation();
    } else {
      await customRequest();
    }
    await _refreshLocationPermission();
  }

  void _onPeopleStateChanged(PeopleListState state, List<SavedPlace> places) {
    if (!mounted) return;
    setState(() {
      _peopleState = state;
      _places = places;
      _placesState = PlacesListState(
        places: places,
        isLoading: state.isLoading,
        hasError: state.hasError,
      );
    });
  }

  void _onPlacesChanged(List<SavedPlace> places) {
    if (!mounted) return;
    setState(() {
      _places = List.of(places);
      _placesState = PlacesListState(places: places);
    });
    _mapScreenKey.currentState?.updatePlaces(places);
  }

  Future<List<SavedPlace>> _refreshPlaces() async {
    final repository = _geofenceRepository;
    if (repository == null) {
      throw StateError('No authenticated server session.');
    }
    final places = await repository.list();
    _onPlacesChanged(places);
    return places;
  }

  Future<void> _startPlaceCreation(PlaceCreationMode mode) async {
    setState(() => _selectedTab = 0);
    _updateLiveTrackingVisibility();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        unawaited(_mapScreenKey.currentState?.startPlaceCreation(mode));
      }
    });
  }

  Future<void> _savePlace(
    String name,
    String area,
    SavedPlaceSource source,
  ) async {
    final repository = _geofenceRepository;
    if (repository == null) {
      throw StateError('No authenticated server session.');
    }
    await repository.create(name: name, area: area);
    try {
      await _refreshPlaces();
    } on Object {
      if (!mounted) return;
      setState(() {
        _placesState = PlacesListState(places: _places, hasError: true);
      });
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            content: Text('Place saved, but the list could not refresh.'),
          ),
        );
    }
  }

  void _selectPersonFromPeople(PersonMapEntry person) {
    if (person.position == null) return;
    setState(() => _selectedTab = 0);
    _updateLiveTrackingVisibility();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        unawaited(_mapScreenKey.currentState?.selectPerson(person.personId));
      }
    });
  }

  Future<void> _refreshPeople() async {
    await _mapScreenKey.currentState?.refresh();
  }

  Widget _profileAvatar() {
    final profile = _settingsState?.profile;
    final imageRef = profile?.profileImageRef;
    if (imageRef == null || _mapRepository == null) {
      return CircleAvatar(
        child: Text(
          (profile?.displayName.isNotEmpty ?? false)
              ? profile!.displayName.characters.first.toUpperCase()
              : '?',
        ),
      );
    }
    return FutureBuilder<Uint8List>(
      future: _avatarImage,
      builder: (context, snapshot) => CircleAvatar(
        backgroundImage: snapshot.hasData ? MemoryImage(snapshot.data!) : null,
        child: snapshot.hasData
            ? null
            : Text(profile!.displayName.characters.first.toUpperCase()),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(_selectedTab == 0 ? 'Trakkar' : _tabNames[_selectedTab]),
      actions: [
        Padding(
          padding: const EdgeInsets.only(right: 12),
          child: Center(child: _profileAvatar()),
        ),
      ],
    ),
    body: Column(
      children: [
        if (_serverConnectionFailed ||
            (widget.controller.isProceedingAnyway &&
                !widget.controller.hasAuthenticatedSession &&
                widget.controller.failure?.isRejectedCredentials != true))
          ServerConnectionBanner(
            message: 'Connection to server failed',
            actionLabel: 'Retry',
            onAction: _retryServerConnection,
          ),
        if (!_locationReady)
          ServerConnectionBanner(
            message: 'Always and Precise location permission is needed.',
            actionLabel: 'Re-ask',
            onAction: _requestLocationAccess,
          ),
        Expanded(
          child: Stack(
            fit: StackFit.expand,
            children:
                [
                  MapScreen(
                    key: _mapScreenKey,
                    repository: _mapRepository,
                    satelliteThresholdZoom: _satelliteThreshold,
                    onSatelliteUnavailable: (value) {
                      if (mounted && _satelliteUnavailable != value) {
                        setState(() => _satelliteUnavailable = value);
                      }
                    },
                    onPeopleStateChanged: (state, places) {
                      _onPeopleStateChanged(state, places);
                      _liveTracking?.setDevices(
                        state.people.map((person) => person.deviceId),
                      );
                    },
                    onSavePlace: _savePlace,
                    styleLoader: widget.mapStyleLoader,
                  ),
                  PeopleScreen(
                    state: _peopleState,
                    places: _places,
                    onPersonSelected: _selectPersonFromPeople,
                    onRefresh: _refreshPeople,
                    imageLoader: _mapRepository?.loadProfileImage,
                  ),
                  PlacesScreen(
                    state: _placesState,
                    repository: _geofenceRepository,
                    onRefresh: _refreshPlaces,
                    onPlacesChanged: _onPlacesChanged,
                    onCreateRequested: _startPlaceCreation,
                  ),
                  SettingsScreen(
                    state: _settingsState,
                    themeController: _themeController,
                    serverDetails: _serverDetails,
                    mapAppearance: MapAppearancePreference(
                      satelliteThresholdZoom: _satelliteThreshold,
                    ),
                    onThresholdChanged: (value) =>
                        unawaited(_saveMapPreference(value)),
                    onReset: _resetApp,
                    onProfileChanged: () {
                      _mapScreenKey.currentState?.refresh();
                      if (mounted) setState(() {});
                    },
                    imageLoader: _mapRepository?.loadProfileImage,
                  ),
                ].asMap().entries.map((entry) {
                  final index = entry.key;
                  final visible = _selectedTab == index;
                  return Positioned.fill(
                    child: IgnorePointer(
                      ignoring: !visible,
                      child: TickerMode(
                        enabled: visible,
                        child: AnimatedOpacity(
                          opacity: visible ? 1 : 0,
                          duration: const Duration(milliseconds: 180),
                          curve: Curves.easeInOut,
                          child: ExcludeSemantics(
                            excluding: !visible,
                            child: entry.value,
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
          ),
        ),
        if (widget.controller.isProceedingAnyway &&
            !widget.controller.hasAuthenticatedSession)
          Padding(
            padding: const EdgeInsets.all(8),
            child: TextButton(
              onPressed: widget.controller.retry,
              child: const Text('Retry authentication'),
            ),
          ),
      ],
    ),
    bottomNavigationBar: NavigationBar(
      selectedIndex: _selectedTab,
      onDestinationSelected: (index) {
        setState(() => _selectedTab = index);
        _updateLiveTrackingVisibility();
      },
      destinations: const [
        NavigationDestination(icon: Icon(Icons.map_outlined), label: 'Map'),
        NavigationDestination(
          icon: Icon(Icons.people_outline),
          label: 'People',
        ),
        NavigationDestination(
          icon: Icon(Icons.place_outlined),
          label: 'Places',
        ),
        NavigationDestination(
          icon: Icon(Icons.settings_outlined),
          label: 'Settings',
        ),
      ],
    ),
  );
}
