# Person pane regression

Boot an iOS simulator, then run:

```sh
flutter drive --driver=test_driver/person_sheet.dart --target=integration_test/person_sheet_test.dart -d <simulator-id>
```

The test uses a local sample person and location without signing in. It checks
that the bottom action is visible, stays above navigation, and responds to taps
after expanding the pane and switching tabs. Screenshots are saved under
`build/person-sheet-screenshots/`.

For phone sizes and larger text in landscape, run
`flutter test test/screens/person_sheet_test.dart`.

## Native iOS person pane system regression

```sh
scripts/test_ios_person_pane.sh <simulator-UDID>
```

XCUITest launches the real app shell with a local sample person and native UIKit
glass. It opens the person pane, swipes it up and down with real iOS touches,
and verifies that the pane surface extends behind the bottom menu while its
scrollable content and action stay above it. It also taps the action, cancels
the dialog, switches tabs through the menu, and reopens the pane.

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
