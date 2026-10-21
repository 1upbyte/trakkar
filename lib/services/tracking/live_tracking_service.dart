import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;

/// Map-view leases. Position collection and uploads remain native SDK work.
class LiveTrackingService {
  LiveTrackingService({
    required this.sessionCookie,
    required this.uniqueId,
    required this.endpoint,
    http.Client? client,
    this.channel = const MethodChannel('trakkar/live_tracking'),
  }) : _client = client ?? http.Client(),
       _viewId = List.generate(
         24,
         (_) => Random.secure().nextInt(256).toRadixString(16).padLeft(2, '0'),
       ).join();

  final String sessionCookie;
  final String uniqueId;
  final String endpoint;
  final http.Client _client;
  final MethodChannel channel;
  final String _viewId;
  Timer? _timer;
  Set<int> _devices = {};
  bool _visible = false;
  bool _disposed = false;
  bool _resetting = false;
  bool _busy = false;
  Future<void>? _registering;
  int? _registeredDeviceId;
  String? _registeredPushToken;

  bool get enabled => endpoint.isNotEmpty;

  Uri _uri(String path) {
    final base = Uri.parse(endpoint);
    if (base.scheme != 'https' || base.host.isEmpty) {
      throw const FormatException('Live tracking URL must use HTTPS');
    }
    return base.replace(
      path: '${base.path.replaceFirst(RegExp(r'/+$'), '')}$path',
    );
  }

  Map<String, String> get _headers => {
    'X-Traccar-Session': sessionCookie,
    'Content-Type': 'application/json',
  };

  Future<void> register() {
    final pending = _registering;
    if (pending != null) return pending;
    final operation = _register();
    _registering = operation;
    return operation.whenComplete(() => _registering = null);
  }

  Future<void> _register() async {
    if (!enabled || _disposed || _resetting) return;
    try {
      final token = await channel.invokeMethod<String>('pushToken');
      if (token == null || token.isEmpty || token == _registeredPushToken) {
        return;
      }
      final response = await _client
          .post(
            _uri('/v1/devices'),
            headers: _headers,
            body: jsonEncode({
              'uniqueId': uniqueId,
              'platform': defaultTargetPlatform == TargetPlatform.iOS
                  ? 'ios'
                  : 'android',
              'pushToken': token,
            }),
          )
          .timeout(const Duration(seconds: 10));
      if (response.statusCode != 200 || _disposed || _resetting) return;
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      await channel.invokeMethod<void>('register', {
        'endpoint': endpoint,
        'deviceToken': data['deviceToken'],
      });
      _registeredDeviceId = data['deviceId'] as int;
      _registeredPushToken = token;
    } on Object {
      // Optional service failure must not interrupt ordinary SDK tracking.
      debugPrint('Live tracking registration unavailable.');
    }
  }

  void setDevices(Iterable<int> ids) {
    final next = ids.where((id) => id > 0).toSet();
    if (setEquals(next, _devices)) return;
    _devices = next;
    if (_visible) unawaited(_renew());
  }

  void setVisible(bool visible) {
    if (_disposed || !enabled || visible == _visible) return;
    _visible = visible;
    _timer?.cancel();
    _timer = null;
    if (visible) {
      unawaited(_renew());
      _timer = Timer.periodic(
        const Duration(seconds: 15),
        (_) => unawaited(_renew()),
      );
    } else {
      unawaited(_release());
    }
  }

  Future<void> _renew() async {
    if (_busy || !_visible || _disposed || _resetting) return;
    _busy = true;
    try {
      await register();
      if (!_visible || _disposed || _resetting) return;
      await _client
          .put(
            _uri('/v1/views/$_viewId'),
            headers: _headers,
            body: jsonEncode({'deviceIds': _devices.toList()}),
          )
          .timeout(const Duration(seconds: 10));
    } on Object {
      debugPrint('Live tracking session renewal unavailable.');
    } finally {
      _busy = false;
      // A renewal already in flight can finish after the user leaves the map.
      if (!_visible && !_disposed) await _release();
    }
  }

  Future<void> _release() async {
    try {
      await _client
          .delete(_uri('/v1/views/$_viewId'), headers: _headers)
          .timeout(const Duration(seconds: 5));
    } on Object {
      // The server also expires the lease after 30 seconds without renewals.
    }
  }

  Future<void> unregister() async {
    _resetting = true;
    setVisible(false);
    if (_registeredDeviceId != null) {
      try {
        await _client
            .delete(
              _uri('/v1/devices'),
              headers: _headers,
              body: jsonEncode({'deviceId': _registeredDeviceId}),
            )
            .timeout(const Duration(seconds: 5));
      } on Object {
        /* Locally clearing registration rejects later pushes. */
      }
    }
    _registeredPushToken = null;
    _registeredDeviceId = null;
    try {
      await channel.invokeMethod<void>('clear');
    } on Object {
      /* no native setup */
    }
  }

  void dispose() {
    _disposed = true;
    _visible = false;
    _timer?.cancel();
    // No DELETE is required for correctness: leases have a bounded lifetime.
    _client.close();
  }
}
