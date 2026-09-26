import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:trakkar/features/people/person_row.dart';
import 'package:trakkar/models/person.dart';

void main() {
  testWidgets('shows name, location, initials and stale report time', (
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
          body: PersonRow(
            person: person,
            locationDescription: 'Home',
            onTap: () {},
          ),
        ),
      ),
    );
    expect(find.text('Taylor Doe'), findsOneWidget);
    expect(find.text('Home'), findsOneWidget);
    expect(find.text('TD'), findsOneWidget);
    expect(find.textContaining('Last known'), findsOneWidget);
  });

  testWidgets('loads server portrait and falls back to initials on failure', (
    tester,
  ) async {
    final person = PersonMapEntry(
      personId: '1',
      deviceId: 1,
      displayName: 'Taylor Doe',
      imageRef: 'traccar-media/device/photo.jpg',
      position: null,
      batteryLevel: null,
      fixTime: null,
    );
    String? requested;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PersonRow(
            person: person,
            locationDescription: 'Location unavailable',
            onTap: () {},
            imageLoader: (reference) async {
              requested = reference;
              throw StateError('offline');
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(requested, 'traccar-media/device/photo.jpg');
    expect(find.text('TD'), findsOneWidget);
    expect(find.text('Location unavailable'), findsOneWidget);
  });

  testWidgets('row remains readable at narrow and wide sizes in both themes', (
    tester,
  ) async {
    final person = PersonMapEntry(
      personId: '3',
      deviceId: 3,
      displayName: 'Alexandra Example Person',
      imageRef: null,
      position: const LatLng(35.7, -78.6),
      address: 'A readable address that may wrap onto another line',
      batteryLevel: null,
      fixTime: DateTime.now(),
    );
    for (final size in [const Size(320, 640), const Size(800, 900)]) {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      for (final brightness in [Brightness.light, Brightness.dark]) {
        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData(brightness: brightness),
            home: Scaffold(
              body: PersonRow(
                person: person,
                locationDescription: person.address!,
                onTap: () {},
              ),
            ),
          ),
        );
        expect(find.text('Alexandra Example Person'), findsOneWidget);
        expect(tester.takeException(), isNull);
      }
    }
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
}
