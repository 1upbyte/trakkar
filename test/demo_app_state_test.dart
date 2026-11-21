import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';
import 'package:trakkar/app_state.dart';
import 'package:trakkar/demo/demo_app_state.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
  });

  test('demo mode is off unless requested', () async {
    expect(await resolveDemoMode(), isFalse);
  });

  test('bootstrap skips setup and loads sample people and places', () async {
    await SharedPreferencesAsync().setBool('map.darkMode', true);
    final state = DemoAppState();
    addTearDown(state.dispose);

    await state.bootstrap();

    expect(state.phase, AppPhase.ready);
    expect(state.ownDevice?.name, 'You');
    expect(state.devices, hasLength(5));
    expect(state.positions.keys, containsAll(state.devices.map((d) => d.id)));
    expect(state.namedPlaces.map((p) => p.name), contains('Work'));
    expect(state.isDriving(state.positions[2]!), isTrue);
    expect(state.friendlyPlaceFor(state.positions[3]!), 'Work');
    expect(state.darkMap, isTrue, reason: 'Local appearance still loads');
  });

  test('place edits stay local and reset restores sample data', () async {
    final state = DemoAppState();
    addTearDown(state.dispose);
    await state.bootstrap();

    await state.addNamedPlace(name: 'Cafe', latitude: 40.7, longitude: -73.9);
    expect(state.namedPlaces.map((p) => p.name), contains('Cafe'));
    await state.deleteNamedPlace('1');
    expect(state.namedPlaces.map((p) => p.name), isNot(contains('Home')));

    await state.resetApp();
    expect(state.phase, AppPhase.ready);
    expect(state.namedPlaces.map((p) => p.name), ['Home', 'Work', 'Gym']);
  });
}
