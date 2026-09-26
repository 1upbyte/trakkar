import 'package:flutter/material.dart';
import 'package:flutter_map_vector_tiles/flutter_map_vector_tiles.dart' as vt;
import 'package:flutter_test/flutter_test.dart';
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:trakkar/app/app_shell.dart';
import 'package:trakkar/features/map/map_screen.dart';
import 'package:trakkar/features/people/people_screen.dart';
import 'package:trakkar/models/login_details.dart';
import 'package:trakkar/services/auth/secure_session_store.dart';
import 'package:trakkar/services/auth/setup_controller.dart';
import 'package:trakkar/services/auth/traccar_auth_service.dart';

class _SessionStore implements SessionStore {
  @override
  Future<void> clear() async {}
  @override
  Future<StoredSession?> read() async => null;
  @override
  Future<void> save(LoginDetailsDraft details, String cookie) async {}
}

Future<MapStyleSet> _emptyStyles(String? _) async => MapStyleSet(
  standard: vt.Style(
    theme: const vt.Theme(id: 'test', layers: []),
    providers: const vt.TileProviders({}),
  ),
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'Map and People tabs stay mounted across sizes, themes and transitions',
    (tester) async {
      for (final size in [const Size(320, 640), const Size(800, 900)]) {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        for (final brightness in [Brightness.light, Brightness.dark]) {
          SharedPreferences.setMockInitialValues({});
          final controller = SetupController(
            service: TraccarAuthService(
              client: MockClient((_) async => fail('unexpected')),
            ),
            store: _SessionStore(),
          );
          await tester.pumpWidget(
            MaterialApp(
              theme: ThemeData(brightness: brightness),
              home: AppShell(
                controller: controller,
                locationAccessCheck: () async => true,
                mapStyleLoader: _emptyStyles,
              ),
            ),
          );
          await tester.pumpAndSettle();

          final mapState = tester.state(find.byType(MapScreen));
          await tester.tap(find.text('People').last);
          await tester.pump(const Duration(milliseconds: 220));
          expect(find.text('People').first, findsOneWidget);
          expect(tester.state(find.byType(MapScreen)), same(mapState));
          final peopleState = tester.state(find.byType(PeopleScreen));

          await tester.tap(find.text('Map').last);
          await tester.pump(const Duration(milliseconds: 220));
          expect(tester.state(find.byType(PeopleScreen)), same(peopleState));
          expect(tester.state(find.byType(MapScreen)), same(mapState));
          expect(find.byType(CircularProgressIndicator), findsNothing);

          await tester.pumpWidget(const SizedBox());
          controller.dispose();
        }
      }
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    },
  );
}
