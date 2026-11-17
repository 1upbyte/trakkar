import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trakkar/models/traccar_position.dart';
import 'package:trakkar/widgets/location_freshness_dot.dart';

TraccarPosition _fix(DateTime time, {bool valid = true}) => TraccarPosition(
  id: 1,
  deviceId: 1,
  latitude: 40,
  longitude: -74,
  fixTime: time,
  valid: valid,
);

Widget _app(TraccarPosition? position) => MaterialApp(
  home: Scaffold(body: LocationFreshnessDot(position: position, size: 15)),
);

Color? _dotColor(WidgetTester tester) {
  final container = tester.widget<Container>(
    find.descendant(
      of: find.byType(LocationFreshnessDot),
      matching: find.byType(Container),
    ),
  );
  return (container.decoration! as BoxDecoration).color;
}

void main() {
  testWidgets('expires without another position or parent rebuild', (
    tester,
  ) async {
    await tester.pumpWidget(_app(_fix(DateTime.now())));
    expect(_dotColor(tester), const Color(0xFF36A269));

    await tester.pump(const Duration(seconds: 14));
    expect(_dotColor(tester), const Color(0xFF36A269));
    await tester.pump(const Duration(seconds: 1));
    expect(_dotColor(tester), Colors.grey);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('new GPS fixes renew freshness and an expired dot recovers', (
    tester,
  ) async {
    await tester.pumpWidget(_app(_fix(DateTime.now())));
    await tester.pump(const Duration(seconds: 10));
    await tester.pumpWidget(_app(_fix(DateTime.now())));
    await tester.pump(const Duration(seconds: 6));
    expect(_dotColor(tester), const Color(0xFF36A269));
    await tester.pump(const Duration(seconds: 9));
    expect(_dotColor(tester), Colors.grey);

    await tester.pumpWidget(_app(_fix(DateTime.now())));
    expect(_dotColor(tester), const Color(0xFF36A269));
    // Removing a fresh dot must also cancel its pending expiry.
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('stale, missing, invalid, and future fixes stay gray', (
    tester,
  ) async {
    final now = DateTime.now();
    for (final position in [
      _fix(now.subtract(const Duration(seconds: 20))),
      null,
      _fix(now, valid: false),
      _fix(now.add(const Duration(minutes: 1))),
      const TraccarPosition(
        id: 2,
        deviceId: 1,
        latitude: 40,
        longitude: -74,
        valid: true,
      ),
    ]) {
      await tester.pumpWidget(_app(position));
      expect(_dotColor(tester), Colors.grey);
    }
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
