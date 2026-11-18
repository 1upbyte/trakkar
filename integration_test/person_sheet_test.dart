import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import '../test/support/person_sheet_scenarios.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  // Live map tiles can keep scheduling frames. Advance the pane and tab
  // transitions without waiting for unrelated network rendering to settle.
  Future<void> finishTransitions(WidgetTester tester) async {
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 1));
  }

  testWidgets('person pane keeps its location summary visible on iOS', (
    tester,
  ) async {
    await openPersonSheet(tester);
    await binding.takeScreenshot('person-pane-open');
    expectPersonSummaryVisible(tester);
    expectPersonPaneFitsContent(tester);
    final initialHeight = tester.getSize(personSheetList()).height;
    await scrollPersonSheetToSummary(tester);
    expectPersonPaneFitsContent(tester);
    expect(tester.getSize(personSheetList()).height, closeTo(initialHeight, 1));
    await binding.takeScreenshot('person-pane-dragged');
    await tester.tap(find.text('People').last);
    await finishTransitions(tester);
    expect(personSheetList(), findsNothing);
    await tester.tap(find.text('Map').last);
    await finishTransitions(tester);
    await tester.tap(find.text('A').first);
    await finishTransitions(tester);
    expectPersonSummaryVisible(tester);
    await binding.takeScreenshot('person-pane-reopened');
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
