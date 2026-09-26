# Quickstart Validation: Places Tab

No Flutter project exists in this checkout. From the restored app root:

```sh
flutter pub get
flutter analyze
flutter test
flutter build apk --debug
flutter build ios --simulator
```

The iOS build requires macOS/Xcode and CocoaPods. Focused tests should cover geofence
list/create/delete contracts; valid/invalid polygon conversion; Auto candidate preview,
missing or unusable building outlines and Manual fallback; name validation; cancel behavior;
named delete confirmation; offline/server failure consistency; and map/list refresh only
after successful server changes. Manually verify map attribution, vector-tile cache
reuse, and failure feedback on Android and iOS. See the
[UI contract](contracts/places-ui.md) and [API contract](contracts/traccar-geofence-api.md).
