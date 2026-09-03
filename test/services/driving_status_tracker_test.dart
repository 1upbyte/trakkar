import 'package:flutter_test/flutter_test.dart';
import 'package:trakkar/models/traccar_position.dart';
import 'package:trakkar/services/driving_status_tracker.dart';

void main() {
  var now = DateTime.utc(2026, 9, 2, 12);
  late DrivingStatusTracker tracker;

  setUp(() {
    now = DateTime.utc(2026, 9, 2, 12);
    tracker = DrivingStatusTracker(clock: () => now);
  });

  TraccarPosition position(int id, double speedMph) => TraccarPosition(
    id: id,
    deviceId: 7,
    latitude: 40,
    longitude: -74,
    // Traccar speed is knots.
    speed: speedMph / 1.150779448,
    valid: true,
  );

  test('keeps driving status for one minute below 10 mph', () {
    tracker.record([position(1, 15)]);
    expect(tracker.isDriving(position(1, 15)), isTrue);

    now = now.add(const Duration(seconds: 30));
    final slow = position(2, 5);
    tracker.record([slow]);
    expect(tracker.isDriving(slow), isTrue);

    now = now.add(const Duration(seconds: 59));
    expect(tracker.isDriving(slow), isTrue);

    now = now.add(const Duration(seconds: 1));
    expect(tracker.isDriving(slow), isFalse);
  });

  test('does not extend the grace period for a repeated slow position', () {
    final fast = position(1, 15);
    tracker.record([fast]);

    now = now.add(const Duration(seconds: 10));
    final slow = position(2, 5);
    tracker.record([slow]);
    now = now.add(const Duration(seconds: 45));
    tracker.record([slow]);
    now = now.add(const Duration(seconds: 15));

    expect(tracker.isDriving(slow), isFalse);
  });
}
