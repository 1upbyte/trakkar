import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/traccar_device.dart';

/// Keeps everyone's position fresh while somebody is looking at the map.
///
/// Traccar's REST API does not push device edits over the websocket, so a
/// phone that has the map in the foreground advertises itself by writing a
/// `trakkarWatchUntil` timestamp onto its own device record. Every other
/// phone polls the device list at a slow cadence, and while a fresh watch
/// timestamp from another device exists it asks the official Traccar Client
/// SDK for an immediate position and polls faster.
class LiveWatchCoordinator {
  LiveWatchCoordinator({
    required this.publishWatch,
    required this.fetchDevices,
    required this.sendPosition,
    required this.ownUniqueId,
    this.heartbeatInterval = const Duration(seconds: 30),
    this.watchTtl = const Duration(seconds: 75),
    this.idlePollInterval = const Duration(seconds: 45),
    this.watchedPollInterval = const Duration(seconds: 15),
    this.minimumSendGap = const Duration(seconds: 12),
    DateTime Function()? clock,
    this.onDevices,
  }) : _clock = clock ?? DateTime.now;

  /// Writes the watch expiry to this phone's own device. `null` clears it.
  final Future<void> Function(DateTime? until) publishWatch;

  /// Loads the current device list from the manager account.
  final Future<List<TraccarDevice>> Function() fetchDevices;

  /// Asks the tracking SDK to upload a fresh position now.
  final Future<bool> Function() sendPosition;

  /// Receives every polled device list so callers can refresh their state.
  final void Function(List<TraccarDevice> devices)? onDevices;

  final String Function() ownUniqueId;
  final Duration heartbeatInterval;
  final Duration watchTtl;
  final Duration idlePollInterval;
  final Duration watchedPollInterval;
  final Duration minimumSendGap;
  final DateTime Function() _clock;

  Timer? _heartbeatTimer;
  Timer? _pollTimer;
  bool _watching = false;
  bool _polling = false;
  bool _pollInFlight = false;
  DateTime? _lastSend;

  /// Names of other people whose map is currently open.
  List<String> watchers = const [];

  bool get isWatching => _watching;
  bool get isPolling => _polling;
  bool get watchedByOthers => watchers.isNotEmpty;

  /// Call with true while the map is visible in the foreground.
  Future<void> setWatching(bool watching) async {
    if (_watching == watching) return;
    _watching = watching;
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
    if (watching) {
      await _heartbeat();
      _heartbeatTimer = Timer.periodic(heartbeatInterval, (_) {
        unawaited(_heartbeat());
      });
      // The viewer's own position should be fresh for everyone else too.
      unawaited(_sendThrottled());
    } else {
      try {
        await publishWatch(null);
      } on Object {
        // The expiry timestamp bounds the damage of a failed clear.
      }
    }
  }

  /// Starts the background poll. Safe to call repeatedly.
  void startPolling() {
    if (_polling) return;
    _polling = true;
    _schedulePoll(Duration.zero);
  }

  void stopPolling() {
    _polling = false;
    _pollTimer?.cancel();
    _pollTimer = null;
    watchers = const [];
  }

  /// Evaluates a device list that arrived through another channel, such as a
  /// manual refresh, without waiting for the next poll.
  Future<void> observeDevices(List<TraccarDevice> devices) async {
    final now = _clock();
    final own = ownUniqueId();
    watchers = devices
        .where((device) => device.uniqueId != own && device.isWatchingAt(now))
        .map((device) => device.name)
        .toList(growable: false);
    if (watchedByOthers) {
      await _sendThrottled();
    }
  }

  Future<void> dispose() async {
    _heartbeatTimer?.cancel();
    stopPolling();
    if (_watching) {
      _watching = false;
      try {
        await publishWatch(null);
      } on Object {
        // Best effort only.
      }
    }
  }

  Future<void> _heartbeat() async {
    if (!_watching) return;
    try {
      await publishWatch(_clock().add(watchTtl));
    } on Object catch (error) {
      debugPrint('Watch heartbeat failed: $error');
    }
  }

  void _schedulePoll(Duration delay) {
    _pollTimer?.cancel();
    if (!_polling) return;
    _pollTimer = Timer(delay, () => unawaited(_poll()));
  }

  Future<void> _poll() async {
    if (!_polling || _pollInFlight) return;
    _pollInFlight = true;
    try {
      final devices = await fetchDevices();
      onDevices?.call(devices);
      await observeDevices(devices);
    } on Object catch (error) {
      debugPrint('Watch poll failed: $error');
    } finally {
      _pollInFlight = false;
      _schedulePoll(watchedByOthers ? watchedPollInterval : idlePollInterval);
    }
  }

  Future<void> _sendThrottled() async {
    final now = _clock();
    final last = _lastSend;
    if (last != null && now.difference(last) < minimumSendGap) return;
    _lastSend = now;
    try {
      await sendPosition();
    } on Object catch (error) {
      debugPrint('Watch position upload failed: $error');
    }
  }
}
