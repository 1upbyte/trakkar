import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';
import 'package:trakkar/app_state.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('dark map persists and survives satellite-only changes', () async {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
    final state = AppState();
    addTearDown(state.dispose);
    final preferences = SharedPreferencesAsync();

    expect(state.darkMap, isFalse);
    await state.saveMapAppearance(
      satelliteAutoAtStreetZoom: true,
      darkMap: true,
    );
    expect(state.darkMap, isTrue);
    expect(await preferences.getBool('map.darkMode'), isTrue);

    await state.saveMapAppearance(satelliteAutoAtStreetZoom: false);
    expect(state.darkMap, isTrue);
    expect(await preferences.getBool('map.darkMode'), isTrue);
    expect(state.satelliteAutoAtStreetZoom, isFalse);

    await state.saveMapAppearance(
      satelliteAutoAtStreetZoom: false,
      darkMap: false,
    );
    expect(state.darkMap, isFalse);
    expect(await preferences.getBool('map.darkMode'), isFalse);
  });
  test(
    'satellite threshold, permanent mode, and rapid updates persist',
    () async {
      SharedPreferencesAsyncPlatform.instance =
          InMemorySharedPreferencesAsync.empty();
      final state = AppState();
      addTearDown(state.dispose);
      final first = state.saveMapAppearance(satelliteZoom: 16);
      final second = state.saveMapAppearance(satelliteZoom: 18);
      expect(state.satelliteAtZoom(17.5), isFalse);
      expect(state.satelliteAtZoom(18), isTrue);
      await Future.wait([first, second]);
      expect(await SharedPreferencesAsync().getDouble('map.satelliteZoom'), 18);
      await state.saveMapAppearance(
        satelliteAlways: true,
        satelliteAutoAtStreetZoom: false,
      );
      expect(state.satelliteAtZoom(2), isTrue);
      expect(
        await SharedPreferencesAsync().getBool('map.satelliteAlways'),
        isTrue,
      );
      await state.saveMapAppearance(satelliteAlways: false);
      expect(state.satelliteAtZoom(21), isFalse);
    },
  );

  test(
    'slider endpoints select never and always without losing the threshold',
    () async {
      SharedPreferencesAsyncPlatform.instance =
          InMemorySharedPreferencesAsync.empty();
      final state = AppState();
      addTearDown(state.dispose);
      final preferences = SharedPreferencesAsync();

      await state.saveMapAppearance(satelliteSliderValue: 18.5);
      await state.saveMapAppearance(
        satelliteSliderValue: AppState.satelliteSliderMin,
      );
      expect(state.satelliteSliderValue, AppState.satelliteSliderMin);
      for (final zoom in [0.0, 2.0, 19.0, 21.0, 30.0]) {
        expect(state.satelliteAtZoom(zoom), isFalse);
      }
      expect(await preferences.getBool('map.satelliteAlways'), isFalse);
      expect(
        await preferences.getBool('map.satelliteAutoAtStreetZoom'),
        isFalse,
      );
      expect(await preferences.getDouble('map.satelliteZoom'), 18.5);

      await state.saveMapAppearance(
        satelliteSliderValue: AppState.satelliteSliderMax,
      );
      expect(state.satelliteSliderValue, AppState.satelliteSliderMax);
      for (final zoom in [0.0, 2.0, 19.0, 21.0, 30.0]) {
        expect(state.satelliteAtZoom(zoom), isTrue);
      }
      expect(await preferences.getBool('map.satelliteAlways'), isTrue);
      expect(await preferences.getDouble('map.satelliteZoom'), 18.5);

      // Every old numeric position, including 2 and 21, remains automatic.
      for (var zoom = 2.0; zoom <= 21; zoom += 0.5) {
        await state.saveMapAppearance(satelliteSliderValue: zoom);
        expect(state.satelliteSliderValue, zoom);
        expect(state.satelliteAtZoom(zoom - 0.5), isFalse);
        expect(state.satelliteAtZoom(zoom), isTrue);
        expect(state.satelliteAlways, isFalse);
        expect(state.satelliteAutoAtStreetZoom, isTrue);
        expect(await preferences.getDouble('map.satelliteZoom'), zoom);
      }
    },
  );

  test(
    'existing satellite switch preferences map to slider endpoints',
    () async {
      SharedPreferencesAsyncPlatform.instance =
          InMemorySharedPreferencesAsync.empty();
      final state = AppState();
      addTearDown(state.dispose);
      await state.saveMapAppearance(satelliteAutoAtStreetZoom: false);
      expect(state.satelliteSliderValue, AppState.satelliteSliderMin);
      await state.saveMapAppearance(satelliteAlways: true);
      expect(state.satelliteSliderValue, AppState.satelliteSliderMax);
      await state.saveMapAppearance(
        satelliteAlways: false,
        satelliteAutoAtStreetZoom: true,
      );
      expect(state.satelliteSliderValue, 19);
    },
  );
}
