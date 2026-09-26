import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:trakkar/features/places/manual_place_editor.dart';

const _validBoundary = [
  LatLng(35.7, -78.6),
  LatLng(35.7, -78.59),
  LatLng(35.71, -78.59),
];

void main() {
  testWidgets('invalid boundary explains correction and cannot be saved', (
    tester,
  ) async {
    var saved = false;
    var removed = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ManualPlaceEditor(
            points: const [LatLng(35.7, -78.6)],
            validationError: 'Add at least three different corners.',
            isSaving: false,
            onRemoveLast: () => removed = true,
            onCancel: () {},
            onSave: (_) async => saved = true,
          ),
        ),
      ),
    );
    expect(find.text('1 corners'), findsOneWidget);
    expect(find.text('Add at least three different corners.'), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'Home');
    await tester.pump();
    expect(
      tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
      isNull,
    );
    await tester.tap(find.text('Undo corner'));
    expect(removed, isTrue);
    expect(saved, isFalse);
  });

  testWidgets(
    'valid boundary accepts name and exposes corner editing feedback',
    (tester) async {
      String? savedName;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ManualPlaceEditor(
              points: _validBoundary,
              validationError: null,
              isSaving: false,
              onRemoveLast: () {},
              onCancel: () {},
              onSave: (name) async => savedName = name,
            ),
          ),
        ),
      );
      expect(
        find.text('Tap the map to add corners. Drag a corner to move it.'),
        findsOneWidget,
      );
      await tester.enterText(find.byType(TextField), '  Home  ');
      await tester.pump();
      await tester.tap(find.text('Save place'));
      expect(savedName, 'Home');
    },
  );
}
