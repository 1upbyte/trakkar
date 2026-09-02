import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';
import 'package:trakkar/app_state.dart';
import 'package:trakkar/models/named_place.dart';
import 'package:trakkar/models/theme_preference.dart';
import 'package:trakkar/models/traccar_device.dart';
import 'package:trakkar/models/traccar_position.dart';
import 'package:trakkar/screens/people_screen.dart';

void main() {
  testWidgets('lists every person and prefers a friendly place', (
    tester,
  ) async {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
    final state = AppState();
    addTearDown(state.dispose);
    expect(state.themePreference, ThemePreference.system);

    state.devices = const [
      TraccarDevice(
        id: 1,
        name: 'Alex',
        uniqueId: 'alex',
        status: 'online',
        raw: {},
      ),
      TraccarDevice(
        id: 2,
        name: 'Blake',
        uniqueId: 'blake',
        status: 'offline',
        raw: {},
      ),
    ];
    state.positions = const {
      1: TraccarPosition(
        id: 10,
        deviceId: 1,
        latitude: 40.7128,
        longitude: -74.0060,
        valid: true,
      ),
    };
    state.namedPlaces = const [
      NamedPlace(
        id: 'home',
        name: 'Home',
        latitude: 40.7128,
        longitude: -74.0060,
        radiusMeters: 150,
      ),
    ];

    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: state,
        child: const MaterialApp(home: Scaffold(body: PeopleScreen())),
      ),
    );

    expect(find.text('Alex'), findsOneWidget);
    expect(find.text('Home'), findsOneWidget);
    expect(find.text('Blake'), findsOneWidget);
    expect(find.text('No location reported'), findsOneWidget);
  });
}
