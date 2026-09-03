import '../models/traccar_position.dart';

class DrivingStatusTracker {
  DrivingStatusTracker({
    this.slowSpeedGrace = const Duration(minutes: 1),
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now;

  final Duration slowSpeedGrace;
  final DateTime Function() _clock;
  final Map<int, int> _lastPositionIds = <int, int>{};
  final Set<int> _drivingDevices = <int>{};
  final Map<int, DateTime> _drivingUntil = <int, DateTime>{};

  void record(Iterable<TraccarPosition> positions) {
    final now = _clock();
    for (final position in positions) {
      if (_lastPositionIds[position.deviceId] == position.id) continue;
      _lastPositionIds[position.deviceId] = position.id;
      if (position.speedMph >= 10) {
        _drivingDevices.add(position.deviceId);
        _drivingUntil.remove(position.deviceId);
      } else if (_drivingDevices.contains(position.deviceId)) {
        _drivingUntil.putIfAbsent(
          position.deviceId,
          () => now.add(slowSpeedGrace),
        );
      }
    }
    _removeExpired(now);
  }

  bool isDriving(TraccarPosition position) {
    if (position.speedMph >= 10) return true;
    final now = _clock();
    _removeExpired(now);
    return _drivingDevices.contains(position.deviceId);
  }

  Duration? get timeUntilNextExpiry {
    final now = _clock();
    _removeExpired(now);
    DateTime? next;
    for (final until in _drivingUntil.values) {
      if (next == null || until.isBefore(next)) next = until;
    }
    return next?.difference(now);
  }

  void clear() {
    _lastPositionIds.clear();
    _drivingDevices.clear();
    _drivingUntil.clear();
  }

  void _removeExpired(DateTime now) {
    final expired = _drivingUntil.entries
        .where((entry) => !entry.value.isAfter(now))
        .map((entry) => entry.key)
        .toList(growable: false);
    for (final deviceId in expired) {
      _drivingUntil.remove(deviceId);
      _drivingDevices.remove(deviceId);
    }
  }
}
