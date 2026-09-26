import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:trakkar/features/map/person_details_sheet.dart';
import 'package:trakkar/models/person.dart';

void main() {
  testWidgets('details show name, location, unknown battery and stale update', (
    tester,
  ) async {
    final person = PersonMapEntry(
      personId: '1',
      deviceId: 1,
      displayName: 'Taylor Doe',
      imageRef: null,
      position: const LatLng(35.7, -78.6),
      batteryLevel: null,
      fixTime: DateTime.now().subtract(const Duration(hours: 2)),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PersonDetailsSheet(
            person: person,
            locationDescription: Future.value('Home'),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Taylor Doe'), findsOneWidget);
    expect(find.text('Home'), findsOneWidget);
    expect(find.text('Unknown'), findsOneWidget);
    expect(find.textContaining('Last known'), findsOneWidget);
  });

  testWidgets('details show unavailable fields rather than fabricating data', (
    tester,
  ) async {
    const person = PersonMapEntry(
      personId: '2',
      deviceId: 2,
      displayName: 'Casey',
      imageRef: null,
      position: null,
      batteryLevel: null,
      fixTime: null,
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PersonDetailsSheet(
            person: person,
            locationDescription: Future.value('Location unavailable'),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Location unavailable'), findsOneWidget);
    expect(find.text('Unknown'), findsNWidgets(2));
  });
}
