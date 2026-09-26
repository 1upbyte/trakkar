import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:trakkar/features/places/places_list_state.dart';
import 'package:trakkar/features/places/places_screen.dart';
import 'package:trakkar/models/place_creation_draft.dart';
import 'package:trakkar/models/saved_place.dart';
import 'package:trakkar/services/places/geofence_repository.dart';

const _home = SavedPlace(
  id: 1,
  name: 'Home',
  points: [LatLng(35.7, -78.6)],
  circleRadiusMeters: 100,
);

class _FakeGeofences implements GeofenceRepository {
  _FakeGeofences(this.places, {this.failDelete = false});

  List<SavedPlace> places;
  bool failDelete;
  final deletes = <int>[];

  @override
  Future<List<SavedPlace>> list() async => places;

  @override
  Future<void> create({required String name, required String area}) async {}

  @override
  Future<void> delete(int id) async {
    deletes.add(id);
    if (failDelete) throw StateError('private server detail');
    places = places.where((place) => place.id != id).toList();
  }
}

void main() {
  testWidgets(
    'delete confirmation names the place and cancel does not mutate',
    (tester) async {
      final repository = _FakeGeofences([_home]);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PlacesScreen(
              state: PlacesListState(places: [_home]),
              repository: repository,
              onRefresh: repository.list,
              onPlacesChanged: (_) {},
              onCreateRequested: (_) async {},
            ),
          ),
        ),
      );
      await tester.tap(find.byIcon(Icons.delete_outline));
      await tester.pumpAndSettle();
      expect(find.text('Delete Home?'), findsOneWidget);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(repository.deletes, isEmpty);
      expect(find.text('Home'), findsOneWidget);
    },
  );

  testWidgets(
    'successful delete removes place only after server confirmation',
    (tester) async {
      final repository = _FakeGeofences([_home]);
      var places = <SavedPlace>[_home];
      await tester.pumpWidget(
        MaterialApp(
          home: StatefulBuilder(
            builder: (context, setState) => Scaffold(
              body: PlacesScreen(
                state: PlacesListState(places: places),
                repository: repository,
                onRefresh: repository.list,
                onPlacesChanged: (value) => setState(() => places = value),
                onCreateRequested: (_) async {},
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.byIcon(Icons.delete_outline));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete').last);
      await tester.pumpAndSettle();
      expect(repository.deletes, [1]);
      expect(places, isEmpty);
      expect(find.text('Home'), findsNothing);
    },
  );

  testWidgets(
    'delete failure reconciles server state and shows safe feedback',
    (tester) async {
      final repository = _FakeGeofences([_home], failDelete: true);
      var places = <SavedPlace>[_home];
      await tester.pumpWidget(
        MaterialApp(
          home: StatefulBuilder(
            builder: (context, setState) => Scaffold(
              body: PlacesScreen(
                state: PlacesListState(places: places),
                repository: repository,
                onRefresh: repository.list,
                onPlacesChanged: (value) => setState(() => places = value),
                onCreateRequested: (_) async {},
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.byIcon(Icons.delete_outline));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete').last);
      await tester.pumpAndSettle();
      expect(places.map((place) => place.name), ['Home']);
      expect(find.text('Home'), findsOneWidget);
      expect(find.textContaining('private server detail'), findsNothing);
      expect(
        find.text('Could not delete place. Server data was refreshed.'),
        findsOneWidget,
      );
    },
  );

  testWidgets('Add offers Auto and Manual creation modes', (tester) async {
    var requested = <PlaceCreationMode>[];
    final repository = _FakeGeofences([]);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PlacesScreen(
            state: PlacesListState(places: const []),
            repository: repository,
            onRefresh: repository.list,
            onPlacesChanged: (_) {},
            onCreateRequested: (mode) async => requested.add(mode),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Add place'));
    await tester.pumpAndSettle();
    expect(find.text('Auto'), findsOneWidget);
    expect(find.text('Manual'), findsOneWidget);
    await tester.tap(find.text('Manual'));
    await tester.pumpAndSettle();
    expect(requested, [PlaceCreationMode.manual]);
  });
}
