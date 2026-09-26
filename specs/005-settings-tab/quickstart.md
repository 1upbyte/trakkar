# Quickstart Validation Guide

## Checkout limitation

This checkout currently has no `pubspec.yaml`, `lib/`, `ios/`, or `android/` project.
The commands below are the validation sequence for the restored/implemented Flutter
application; they cannot run successfully from this Spec Kit-only tree. iOS builds
require macOS with Xcode and CocoaPods. Android builds require Flutter and Android SDK
tooling. Pin and install the Flutter SDK version selected by the actual project.

## Setup and static validation

From the Flutter app root:

```sh
flutter doctor -v
flutter pub get
flutter analyze
flutter test
```

Expected result: dependencies resolve, static analysis is clean, and focused tests
cover profile success/failure and cancellation, all theme modes and persistence,
satellite threshold default/persistence/reset restoration to zoom 19,
server-detail redaction, reset confirmation/cancel/failure, preservation of SDK queued
positions, and routing to first-run only after successful reset.

## Android compile

```sh
flutter build apk --debug
```

Expected result: the Flutter Android host and the Traccar plugin compile for the
configured Android minimum SDK. For a release artifact with signing configured:

```sh
flutter build appbundle
```

## iOS compile

On macOS with Xcode selected and CocoaPods installed:

```sh
flutter build ios --simulator
```

Expected result: the iOS host, plugin, permissions/background configuration, and any
SDK configuration bridge compile for the configured iOS deployment target. For a
device/archive artifact with signing configured:

```sh
flutter build ipa
```

## Manual end-to-end checks

1. Launch as a signed-in user and verify Settings is the last bottom tab.
2. Change the display name and image; verify the name's server save result, the image
   upload and server save, and that both values propagate to every profile surface.
   Cancel image selection and verify the existing image remains.
3. Select System, Light, and Dark, restart the app, and verify the saved mode applies;
   with System selected, change the OS appearance and verify the app follows it.
4. Verify the map satellite threshold starts at zoom 19, change it in Settings, and
   verify the Map tab uses the saved value. Confirmed Reset App restores zoom 19.
5. Inspect server details and verify client URL, manager URL, and account name appear
   when available while passwords and tokens remain absent.
6. Open Reset App, cancel, and verify no state changed. Confirm reset and verify the
   app returns to first-run, server-side account/profile/profile-image/places/tracking data remain,
   queued SDK positions remain present, and the reset flow does not direct those old
   positions to a different server/account.
7. Repeat platform-dependent checks on Android and iOS, including denied/revoked
   tracking permission and interruption while reset is in progress.

See [Settings UI contract](contracts/settings-ui.md),
[Traccar API and SDK contract](contracts/traccar-api.md), and
[data model](data-model.md) for expected behavior.
