import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:trakkar/widgets/platform_controls.dart';

import '../test/support/person_sheet_scenarios.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'Android person pane fits its content before and after dragging',
    (tester) async {
      expect(defaultTargetPlatform, TargetPlatform.android);
      await openPersonSheet(tester);
      await binding.convertFlutterSurfaceToImage();
      await tester.pump();
      await binding.takeScreenshot('android-person-pane-open');
      expectPersonActionVisible(tester);

      final action = find.ancestor(
        of: find.text('Give this place a friendly name'),
        matching: find.byType(PlatformButton),
      );
      void expectFitsContent() {
        final viewport = tester.getRect(personSheetList());
        final gap = viewport.bottom - tester.getRect(action).bottom;
        debugPrint(
          'Android person pane: ${viewport.height.toStringAsFixed(1)} logical '
          'pixels; space below action: ${gap.toStringAsFixed(1)}',
        );
        expectPersonPaneFitsContent(tester);
      }

      expectFitsContent();
      final initialHeight = tester.getSize(personSheetList()).height;
      await scrollPersonSheetToAction(tester);
      await binding.takeScreenshot('android-person-pane-dragged');
      expectFitsContent();
      expect(
        tester.getSize(personSheetList()).height,
        closeTo(initialHeight, 1),
      );
      await tester.tap(find.text('People').last);
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      expect(personSheetList(), findsNothing);
      await tester.tap(find.text('Map').last);
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      await tester.tap(find.text('A').first);
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      await tester.drag(personSheetDragHandle(), const Offset(0, 280));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      expect(personSheetList(), findsNothing);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}
