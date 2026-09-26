import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:trakkar/features/people/people_list_state.dart';
import 'package:trakkar/features/people/people_screen.dart';
import 'package:trakkar/models/person.dart';

PersonMapEntry person(String id, LatLng? position) => PersonMapEntry(
  personId: id,
  deviceId: int.parse(id),
  displayName: 'Person $id',
  imageRef: null,
  position: position,
  batteryLevel: null,
  fixTime: null,
);

void main() {
  testWidgets('located row invokes shared person-selection callback', (
    tester,
  ) async {
    PersonMapEntry? selected;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PeopleScreen(
            state: PeopleListState(
              people: [person('1', const LatLng(35.7, -78.6))],
            ),
            places: const [],
            onPersonSelected: (value) => selected = value,
            onRefresh: () async {},
          ),
        ),
      ),
    );
    await tester.tap(find.text('Person 1'));
    expect(selected?.personId, '1');
  });

  testWidgets('missing location remains visible and explains no map position', (
    tester,
  ) async {
    var selected = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PeopleScreen(
            state: PeopleListState(people: [person('2', null)]),
            places: const [],
            onPersonSelected: (_) => selected = true,
            onRefresh: () async {},
          ),
        ),
      ),
    );
    await tester.tap(find.text('Person 2'));
    await tester.pump();
    expect(find.text('Location is unavailable.'), findsOneWidget);
    expect(selected, isFalse);
  });
}
