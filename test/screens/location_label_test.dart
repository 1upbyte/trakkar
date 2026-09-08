import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trakkar/models/traccar_position.dart';
import 'package:trakkar/widgets/location_label.dart';

void main() {
  testWidgets('failed geocoding retains coordinates and refreshes update age', (
    tester,
  ) async {
    final address = Completer<String>();
    await tester.pumpWidget(
      MaterialApp(
        home: LocationLabel(
          position: TraccarPosition(
            id: 1,
            deviceId: 1,
            latitude: 40,
            longitude: -74,
            valid: true,
            fixTime: DateTime.now().subtract(const Duration(minutes: 5)),
          ),
          address: address.future,
        ),
      ),
    );
    address.completeError(Exception('Offline'));
    await tester.pump();
    expect(
      find.textContaining('40.00000, -74.00000 · Updated 5m ago'),
      findsOneWidget,
    );
    expect(find.text('Location unavailable'), findsNothing);
    await tester.pumpWidget(const SizedBox());
  });

  test('age handles old, missing, and future timestamps', () {
    final now = DateTime.utc(2026, 9, 7);
    expect(positionAge(null, now: now), 'Update time unknown');
    expect(
      positionAge(now.subtract(const Duration(days: 2)), now: now),
      'Updated 2d ago',
    );
    expect(
      positionAge(now.add(const Duration(minutes: 2)), now: now),
      'Updated just now',
    );
  });
}
