import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:trakkar/models/map_appearance_preference.dart';
import 'package:trakkar/models/theme_preference.dart';
import 'package:trakkar/services/settings/preferences_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('defaults to system theme and map threshold 19', () async {
    SharedPreferences.setMockInitialValues({});
    final repository = PreferencesRepository();
    expect(await repository.readTheme(), AppThemePreference.system);
    expect((await repository.readMapAppearance()).satelliteThresholdZoom, 19);
  });

  test('persists all theme choices and map threshold', () async {
    SharedPreferences.setMockInitialValues({});
    final repository = PreferencesRepository();
    for (final preference in AppThemePreference.values) {
      await repository.saveTheme(preference);
      expect(await repository.readTheme(), preference);
    }
    await repository.saveMapAppearance(
      const MapAppearancePreference(satelliteThresholdZoom: 17),
    );
    expect((await repository.readMapAppearance()).satelliteThresholdZoom, 17);
  });

  test(
    'reset restores System and threshold 19 without clearing unrelated keys',
    () async {
      SharedPreferences.setMockInitialValues({'unrelated.setting': 'keep'});
      final repository = PreferencesRepository();
      await repository.saveTheme(AppThemePreference.dark);
      await repository.saveMapAppearance(
        const MapAppearancePreference(satelliteThresholdZoom: 16),
      );
      await repository.reset();
      expect(await repository.readTheme(), AppThemePreference.system);
      expect((await repository.readMapAppearance()).satelliteThresholdZoom, 19);
      expect(
        (await SharedPreferences.getInstance()).getString('unrelated.setting'),
        'keep',
      );
    },
  );
}
