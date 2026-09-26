import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:trakkar/features/map/person_cluster_marker.dart';
import 'package:trakkar/features/map/person_marker.dart';
import 'package:trakkar/models/person.dart';

PersonMapEntry person(int id, String name, {String? image}) => PersonMapEntry(
  personId: '$id',
  deviceId: id,
  displayName: name,
  imageRef: image,
  position: null,
  batteryLevel: null,
  fixTime: null,
);

void main() {
  testWidgets(
    'person marker is circular, identifies the person and is selectable',
    (tester) async {
      final semantics = tester.ensureSemantics();
      var selected = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PersonMarker(
              person: person(1, 'Jordan Doe'),
              onTap: () => selected = true,
            ),
          ),
        ),
      );
      expect(find.text('JD'), findsOneWidget);
      expect(
        find.byWidgetPredicate(
          (widget) =>
              widget is Semantics &&
              widget.properties.label == 'Show Jordan Doe',
        ),
        findsOneWidget,
      );
      await tester.tap(find.byType(GestureDetector).last);
      expect(selected, isTrue);
      semantics.dispose();
    },
  );

  testWidgets('failed profile image loading falls back to initials', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PersonMarker(
            person: person(3, 'Sam Rivers', image: '/api/server/files/avatar'),
            onTap: () {},
            imageLoader: (_) async => Uint8List.fromList([0, 1, 2]),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('SR'), findsOneWidget);
  });

  testWidgets(
    'cluster keeps each member image/initial widget available for selection',
    (tester) async {
      var first = false;
      var second = false;
      final markers = [
        Marker(
          point: const LatLng(0, 0),
          child: PersonMarker(
            person: person(1, 'Ada Lovelace'),
            onTap: () => first = true,
          ),
        ),
        Marker(
          point: const LatLng(0, 0),
          child: PersonMarker(
            person: person(2, 'Grace Hopper'),
            onTap: () => second = true,
          ),
        ),
      ];
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: PersonClusterMarker(markers: markers)),
        ),
      );
      expect(find.text('AL'), findsOneWidget);
      expect(find.text('GH'), findsOneWidget);
      await tester.tap(find.text('AL'));
      await tester.tap(find.text('GH'));
      expect(first, isTrue);
      expect(second, isTrue);
    },
  );
}
