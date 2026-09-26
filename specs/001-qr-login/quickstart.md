# Quickstart Validation: QR Login

Run from the repository root:

```sh
flutter pub get
flutter analyze
flutter test
flutter build apk --debug
flutter build ios --simulator
```

## Validation results (2026-09-26)

- `flutter analyze`: passed.
- `flutter test`: passed all 21 tests for QR parsing, authentication, manual setup, camera permission
  timing, recovery actions, opt-in safe error details, secret redaction, and duplicate
  authentication prevention.
- `flutter build apk --debug`: passed with Android SDK 37. Flutter emitted a future
  compatibility warning because `traccar_client_sdk` applies the Kotlin Gradle Plugin.
- `flutter build ios --simulator`: passed after linking system SQLite for the Traccar
  Client SDK.
- Camera scanning, permission changes on physical devices, background location delivery,
  and authentication against live Traccar services still need device/server verification.

Android and iOS both use the application identifier `com.oneupbyte.trakkar`.

The external QR payload format is documented in the [project README](../../README.md).
See the [setup UI contract](contracts/setup-ui.md) and
[QR payload contract](contracts/qr-payload.md).
