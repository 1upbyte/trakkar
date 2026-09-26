# Quickstart Validation: People Tab

This checkout has no Flutter app source. From the restored app root, run:

```sh
flutter pub get
flutter analyze
flutter test
flutter build apk --debug
flutter build ios --simulator
```

The iOS build requires macOS, Xcode and CocoaPods. Focused tests should cover full
authorized-list rendering, alphabetical order, image/initial fallback, missing and
stale positions, updates while open, map selection equivalence, Back camera restore,
retained list/map contexts, and no blank tab transition. Manually verify on Android and
iOS with a signed-in server session. See the [UI contract](contracts/people-ui.md).
