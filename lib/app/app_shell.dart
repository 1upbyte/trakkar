import 'dart:async';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';

import '../features/map/map_screen.dart';
import '../features/people/people_list_state.dart';
import '../features/people/people_screen.dart';
import '../models/map_appearance_preference.dart';
import '../models/person.dart';
import '../models/saved_place.dart';
import '../services/auth/secure_session_store.dart';
import '../services/auth/setup_controller.dart';
import '../services/map/map_preferences.dart';
import '../services/traccar_data_repository.dart';
import '../services/tracking/traccar_tracking_service.dart';
import '../widgets/server_connection_banner.dart';

class AppShell extends StatefulWidget {
  const AppShell({
    required this.controller,
    this.locationAccessCheck,
    this.onRequestLocationAccess,
    this.mapStyleLoader,
    super.key,
  });

  final SetupController controller;
  final Future<bool> Function()? locationAccessCheck;
  final Future<void> Function()? onRequestLocationAccess;
  final MapStyleLoader? mapStyleLoader;

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> with WidgetsBindingObserver {
  final _tracking = TraccarTrackingService();
  final _sessionStore = SecureSessionStore();
  final _mapPreferences = MapPreferences();
  bool _locationReady = false;
  bool _trackingStarted = false;
  bool _trackingConfigured = false;
  bool _serverConnectionFailed = false;
  bool _satelliteUnavailable = false;
  int _selectedTab = 0;
  double _satelliteThreshold = 19;
  TraccarDataRepository? _mapRepository;
  final _mapScreenKey = GlobalKey<MapScreenState>();
  PeopleListState _peopleState = PeopleListState(
    people: const [],
    isLoading: true,
  );
  List<SavedPlace> _places = const [];

  static const _tabNames = ['Map', 'People', 'Places', 'Settings'];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _refreshLocationPermission();
    unawaited(_loadMapPreference());
    if (widget.controller.hasAuthenticatedSession) {
      unawaited(_configureTracking());
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _refreshLocationPermission();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    unawaited(_mapRepository?.close());
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
        if (mounted) setState(() {});
        await _tracking.configure(stored.details);
        _trackingConfigured = true;
        await _maybeStartTracking();
      }
    } on Object {
      if (mounted) setState(() => _serverConnectionFailed = true);
    }
  }

  Future<void> _loadMapPreference() async {
    final preference = await _mapPreferences.read();
    if (mounted) {
      setState(() => _satelliteThreshold = preference.satelliteThresholdZoom);
    }
  }

  Future<void> _saveMapPreference(double value) async {
    setState(() => _satelliteThreshold = value);
    await _mapPreferences.save(
      MapAppearancePreference(satelliteThresholdZoom: value),
    );
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
        if (mounted) setState(() => _serverConnectionFailed = false);
      } on Object {
        _trackingStarted = false;
        if (mounted) setState(() => _serverConnectionFailed = true);
      }
    }
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
    });
  }

  void _selectPersonFromPeople(PersonMapEntry person) {
    if (person.position == null) return;
    setState(() => _selectedTab = 0);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        unawaited(_mapScreenKey.currentState?.selectPerson(person.personId));
      }
    });
  }

  Future<void> _refreshPeople() async {
    await _mapScreenKey.currentState?.refresh();
  }

  Widget _settingsPage(BuildContext context) => ListView(
    padding: const EdgeInsets.all(20),
    children: [
      Text('Map appearance', style: Theme.of(context).textTheme.titleLarge),
      const SizedBox(height: 12),
      Text(
        'Switch to satellite at zoom ${_satelliteThreshold.toStringAsFixed(0)}',
      ),
      Slider(
        value: _satelliteThreshold,
        min: 15,
        max: 21,
        divisions: 6,
        label: _satelliteThreshold.toStringAsFixed(0),
        onChanged: (value) => unawaited(_saveMapPreference(value)),
      ),
      if (_satelliteUnavailable)
        const Text('Satellite imagery is unavailable from the server.'),
    ],
  );

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(_selectedTab == 0 ? 'Trakkar' : _tabNames[_selectedTab]),
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
                    onPeopleStateChanged: _onPeopleStateChanged,
                    styleLoader: widget.mapStyleLoader,
                  ),
                  PeopleScreen(
                    state: _peopleState,
                    places: _places,
                    onPersonSelected: _selectPersonFromPeople,
                    onRefresh: _refreshPeople,
                    imageLoader: _mapRepository?.loadProfileImage,
                  ),
                  const Center(child: Text('Places')),
                  _settingsPage(context),
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
      onDestinationSelected: (index) => setState(() => _selectedTab = index),
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
