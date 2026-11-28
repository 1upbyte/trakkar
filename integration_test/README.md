# Demo mode for manual UI testing

Run the real app with fake data and no server setup. No signing is needed.

**Xcode (iOS simulator):** open `ios/Runner.xcworkspace`, choose the
**Runner Demo** scheme and any simulator, then press Run. The scheme sets the
`TRAKKAR_DEMO=1` launch variable; the normal **Runner** scheme is unchanged.
Run `flutter pub get` once beforehand if Xcode reports missing Flutter files.

**Command line (any platform):**

```sh
flutter run --dart-define=TRAKKAR_DEMO=true -d <device-id>
```

The launch variable is only honored in the iOS simulator, so device builds can
enter demo mode only through the `--dart-define` flag.

**Your own iPhone with a free Apple ID:** see
[`ios/local-signing/README.md`](../ios/local-signing/README.md).

The app opens straight to the map, signed in as "You", with four sample people
around Manhattan and Brooklyn and three saved places. Alex is driving, Sam and
Jordan are close enough to cluster, and Riley is offline with an old fix.
Adding or deleting places and changing the profile picture only affect
in-memory data. Theme and map appearance settings still save on the device.
Demo mode never contacts a Traccar server, opens the live socket, or starts
native location tracking. Resetting the app in Settings restores the sample data
instead of returning to server setup.

Demo mode is off by default. Builds without the flag behave exactly as before.

# Person pane regression

Boot an iOS simulator, then run:

```sh
flutter drive --driver=test_driver/person_sheet.dart --target=integration_test/person_sheet_test.dart -d <simulator-id>
```

The test uses a local sample person and location without signing in. It checks
that the pane fits its content and keeps its height after an upward drag. It
also checks that the location summary stays above navigation after switching
tabs. Screenshots are saved under
`build/person-sheet-screenshots/`.

For phone sizes and larger text in landscape, run
`flutter test test/screens/person_sheet_test.dart`.

## Android person pane regression

With an Android emulator or test device running:

```sh
flutter drive --driver=test_driver/person_sheet.dart --target=integration_test/android_person_sheet_test.dart -d <android-device-id>
```

The test runs the real Android app with a local sample person. It checks that
the pane wraps its content with only the normal bottom padding, stays the same
height after an upward drag, and closes when its handle is dragged down. It also
checks that the location summary stays visible and the bottom menu remains usable.
Screenshots are saved under `build/person-sheet-screenshots/`. The widget tests
also cover small screens and larger text in landscape, where details must
remain scrollable. Use a dedicated emulator or test device: the fixture
replaces its installed app. Run `flutter run` to restore the normal app.

## Native iOS person pane system regression

```sh
scripts/test_ios_person_pane.sh <simulator-UDID>
```

XCUITest launches the real app shell with a local sample person and native UIKit
glass. It opens the person pane and uses real iOS touches to verify that a swipe
up keeps its height and a swipe down on the handle closes it. The pane surface
extends behind the bottom menu while its scrollable content stays above it.
The test also switches tabs through the menu and reopens the pane.

Build logs and Xcode results, including screenshots of each pane state, are
saved under `build/person-pane-system-test/`. Use a dedicated simulator: the
fixture replaces its installed app. The script restores the normal Flutter
entry point afterward; `flutter run` reinstalls the normal app.

# iOS satellite slider system regression

With Xcode and Flutter installed, choose an iOS simulator from
`xcrun simctl list devices available`, then run from the repository root:

```sh
scripts/test_ios_satellite_slider.sh <simulator-UDID>
```

The script builds `fixtures/map_settings_app.dart` and runs the `SatelliteSlider`
Xcode scheme. XCUITest launches the real Settings screen with native UIKit
controls and real preferences, without provisioning or a server. It drags the
slider in both directions, checks the Flutter threshold label and half-level
steps, relaunches to check persistence, and checks vertical scrolling starting
over the slider. It also checks that the removed satellite switches are absent,
the far left selects Never, the far right selects Always, both modes survive
relaunch, and dragging back into the middle restores automatic switching. The
fixture shows the map's actual satellite decision at zoom 2 and 21 so those
behaviors can be verified without downloading tiles. Every numeric threshold
from 2 to 21 remains available between the two extra endpoint positions.
Touches come from iOS, rather than Flutter's synthetic widget gestures or mocked
method-channel events.

Build logs and Xcode result bundles (including failure screenshots) are saved in
`build/slider-system-test/`. The fixture replaces the simulator's installed app;
use a dedicated simulator. The script restores the normal Xcode entry point
afterward. Run `flutter run` to replace the installed fixture with the normal app.
