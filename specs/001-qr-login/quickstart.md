# Quickstart Validation: QR Login

The current checkout has no Flutter project; run from the restored Flutter app root:

```sh
flutter pub get
flutter analyze
flutter test
flutter build apk --debug
flutter build ios --simulator
```

Verify Android and iOS build metadata both use app identifier
`com.1upbyte.trakkar`.

The iOS simulator build requires macOS, Xcode and CocoaPods. Focused tests should cover
valid payloads in the specified order, malformed Base64, invalid UTF-8,
missing/empty/additional semicolon-delimited fields, semicolon-containing values,
arbitrary non-empty URL values passed through without local validation, immediate sign-in
after valid QR parsing, no request for invalid QR payloads, camera denial and cancel, required-field validation, credential
rejection vs unavailable service, retry, and redaction
of credentials/payloads in logs and errors. Manually test camera scanning on Android
and iOS with real platform permissions. Verify successful credentials are persisted only
in platform secure storage and reused for authentication, and verify that location
permission must be Always and Precise. The external QR payload format is documented in
the [project README](../../README.md). See the [setup UI contract](contracts/setup-ui.md)
and [QR payload contract](contracts/qr-payload.md).
