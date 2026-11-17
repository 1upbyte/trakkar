import 'package:flutter_test/flutter_test.dart';
import 'package:trakkar/models/traccar_position.dart';

void main() {
  TraccarPosition position({
    double speed = 0,
    Map<String, dynamic> attributes = const <String, dynamic>{},
  }) {
    return TraccarPosition(
      id: 1,
      deviceId: 2,
      latitude: 40,
      longitude: -74,
      valid: true,
      speed: speed,
      attributes: attributes,
    );
  }

  test('converts Traccar knots to miles per hour', () {
    expect(position(speed: 10).speedMph, closeTo(11.5078, 0.0001));
  });

  test('uses the standardized motion attribute when present', () {
    expect(position(speed: 0, attributes: {'motion': true}).isMoving, isFalse);
    expect(position(speed: 2, attributes: {'motion': true}).isMoving, isTrue);
    expect(
      position(speed: 20, attributes: {'motion': false}).isMoving,
      isFalse,
    );
  });

  test('falls back to speed while filtering normal GPS drift', () {
    expect(position(speed: 0.5).isMoving, isFalse);
    expect(position(speed: 1).isMoving, isTrue);
  });

  test('freshness requires a valid GPS fix younger than 15 seconds', () {
    final now = DateTime.utc(2026, 11, 17, 12);
    TraccarPosition fix({DateTime? time, bool valid = true}) => TraccarPosition(
      id: 1,
      deviceId: 2,
      latitude: 40,
      longitude: -74,
      valid: valid,
      fixTime: time,
    );

    expect(fix(time: now).isRecent(now: now), isTrue);
    expect(
      fix(time: now.subtract(const Duration(milliseconds: 14999)))
          .isRecent(now: now),
      isTrue,
    );
    expect(
      fix(time: now.subtract(const Duration(seconds: 15))).isRecent(now: now),
      isFalse,
    );
    expect(
      fix(time: now.subtract(const Duration(minutes: 5))).isRecent(now: now),
      isFalse,
    );
    expect(fix().isRecent(now: now), isFalse);
    expect(fix(time: now, valid: false).isRecent(now: now), isFalse);
    expect(
      fix(time: now.add(const Duration(seconds: 1))).isRecent(now: now),
      isFalse,
    );
  });
}
