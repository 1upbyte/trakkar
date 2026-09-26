import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:trakkar/features/places/auto_place_editor.dart';
import 'package:trakkar/features/places/building_lookup.dart';

const _building = BuildingCandidate(
  id: 'building-17',
  name: 'Library',
  points: [LatLng(35.7, -78.6), LatLng(35.7, -78.59), LatLng(35.71, -78.59)],
);

void main() {
  testWidgets('missing building data clearly offers Manual mode', (
    tester,
  ) async {
    var manual = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AutoPlaceEditor(
            candidates: const [],
            selectedId: null,
            isLoading: false,
            isReviewing: false,
            isSaving: false,
            message: 'No building data is available here.',
            onSelect: (_) {},
            onReview: () {},
            onSearchArea: () {},
            onUseManual: () => manual = true,
            onCancel: () {},
            onSave: (_) async {},
          ),
        ),
      ),
    );
    expect(
      find.text('No usable building outlines were found.'),
      findsOneWidget,
    );
    await tester.tap(find.text('Manual'));
    expect(manual, isTrue);
  });

  testWidgets(
    'selects a candidate, reviews its boundary and saves a trimmed name',
    (tester) async {
      var selectedId = null as String?;
      var reviewing = false;
      String? savedName;
      await tester.pumpWidget(
        MaterialApp(
          home: StatefulBuilder(
            builder: (context, setState) => Scaffold(
              body: AutoPlaceEditor(
                candidates: const [_building],
                selectedId: selectedId,
                isLoading: false,
                isReviewing: reviewing,
                isSaving: false,
                onSelect: (candidate) =>
                    setState(() => selectedId = candidate.id),
                onReview: () => setState(() => reviewing = true),
                onSearchArea: () {},
                onUseManual: () {},
                onCancel: () {},
                onSave: (name) async => savedName = name,
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Library'));
      await tester.pump();
      await tester.tap(find.text('Review boundary'));
      await tester.pump();
      expect(
        find.text('Review the highlighted boundary before saving.'),
        findsOneWidget,
      );
      await tester.enterText(find.byType(TextField), '  Branch Office  ');
      await tester.pump();
      await tester.tap(find.text('Save place'));
      expect(savedName, 'Branch Office');
    },
  );
}
