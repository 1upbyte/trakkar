import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';

import '../services/auth/setup_controller.dart';
import '../services/auth/secure_session_store.dart';
import '../services/tracking/traccar_tracking_service.dart';
import '../widgets/server_connection_banner.dart';

class AppShell extends StatefulWidget {
  const AppShell({
    required this.controller,
    this.locationAccessCheck,
    this.onRequestLocationAccess,
    super.key,
  });

  final SetupController controller;
  final Future<bool> Function()? locationAccessCheck;
  final Future<void> Function()? onRequestLocationAccess;

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> with WidgetsBindingObserver {
  final _tracking = TraccarTrackingService();
  final _sessionStore = SecureSessionStore();
  bool _locationReady = false;
  bool _trackingStarted = false;
  bool _trackingConfigured = false;
  bool _serverConnectionFailed = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _refreshLocationPermission();
    if (widget.controller.hasAuthenticatedSession) _configureTracking();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _refreshLocationPermission();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  Future<void> _configureTracking() async {
    try {
      final stored = await _sessionStore.read();
      if (stored != null) {
        await _tracking.configure(stored.details);
        _trackingConfigured = true;
        await _maybeStartTracking();
      }
    } on Object {
      if (mounted) setState(() => _serverConnectionFailed = true);
    }
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

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Trakkar')),
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
        const Expanded(child: Center(child: Text('Map'))),
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
  );
}
