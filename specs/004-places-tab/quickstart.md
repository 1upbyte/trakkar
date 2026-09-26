# Quickstart Validation: Places Tab

Feature 004 is implemented in the Flutter app in this checkout. Run from the
repository root:

```sh
flutter pub get
flutter analyze
flutter test test/models/saved_place_test.dart test/services/places test/features/places
flutter build apk --debug
flutter build ios --debug --no-codesign
```

Validation completed on 2026-09-26:

- `flutter analyze`: passed with no issues.
- Focused Places suite: all 23 tests passed, covering saved-place WKT projection,
  authenticated geofence
  requests, polygon validation and WKT, vector-tile building selection and
  failures, Places list/delete behavior, and Auto/Manual editor widgets.
- `flutter test`: all 79 tests passed.
- `flutter build apk --debug`: passed; produced `build/app/outputs/flutter-apk/app-debug.apk`.
- `flutter build ios --debug --no-codesign`: passed; produced
  `build/ios/iphoneos/Runner.app`. This checks compilation and does not sign or
  deploy to a device.

Auto mode reads the `building` layer from the existing OpenFreeMap vector-tile
style and keeps its attribution visible in the editor. Manual device checks for
map appearance, gestures, and network behavior remain a separate UI validation
step. See the [UI contract](contracts/places-ui.md) and
[API contract](contracts/traccar-geofence-api.md).
