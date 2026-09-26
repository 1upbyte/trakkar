# Settings Tab Validation Guide

## Automated checks

From the Flutter project root:

```sh
flutter pub get
flutter analyze
flutter test test/services/settings test/features/settings test/models/settings_models_test.dart test/app/app_shell_test.dart test/features/setup
flutter build apk --debug
flutter build ios --debug --no-codesign
```

Compile the Android instrumentation test source:

```sh
cd android
./gradlew :app:compileDebugAndroidTestKotlin
```

Compile the iOS XCTest target on macOS with Xcode:

```sh
cd ios
xcodebuild -project Runner.xcodeproj -scheme Runner -destination 'generic/platform=iOS Simulator' build-for-testing CODE_SIGNING_ALLOWED=NO
```

The native test sources check that reset clears the SDK `Config` row only when
there are no pending positions. If positions remain queued, reset fails before
removing the SDK config or local session, allowing those positions to sync with
their existing server before the user retries. The bridge tests compile on both
platforms; runtime/device execution remains a separate check.

## Manual signed-in checks

1. Open Settings and verify it is the last bottom-navigation tab. Confirm the
   current account name and server URLs appear without passwords, tokens, URL
   user-info, query parameters, or fragments.
2. Save a trimmed display name. Select and crop a profile picture, then verify
   the success state appears only after the server device image attribute is
   saved. Cancel image selection and verify the existing image remains. Check
   the app-bar identity on Map, People, Places, and Settings.
3. Select System, Light, and Dark. Verify the theme changes across the whole app
   and System follows OS appearance. Change the satellite threshold and verify
   Map uses the saved value; a new install defaults to zoom 19.
4. Open Reset App and cancel. Confirm no changes occur. For a successful reset,
   confirm the SDK queue is empty, accept the confirmation, and verify the app
   returns to first-run with System theme and threshold 19. Confirm the server
   profile picture, account, places, and tracking data remain.
5. With pending SDK positions, confirm Reset App fails safely, the existing
   session/config remains, and tracking resumes. Let positions sync to the
   current server, then retry reset.
6. Repeat on Android and iOS. Exercise permission denial/revocation, app
   interruption during reset, a failed name/image save, and unavailable server
   details.

See [Settings UI contract](contracts/settings-ui.md),
[Traccar API and SDK contract](contracts/traccar-api.md), and
[data model](data-model.md) for the expected behavior.
