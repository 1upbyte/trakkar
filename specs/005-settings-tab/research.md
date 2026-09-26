# Phase 0 Research: Settings Tab and App Reset

**Research date**: 2026-09-24

## Existing checkout and project assumptions

**Decision**: Treat this repository state as a Spec Kit planning checkout, not as a
buildable Flutter application. Implement against the actual Flutter project's existing
architecture once that source is restored; use the proposed standard Flutter layout in
`plan.md` only if no established layout exists.

**Rationale**: The checkout contains no `pubspec.yaml`, Dart sources, `ios/`, or
`android/` host project, so package versions, existing APIs, native configurations,
and compilation cannot be inspected or validated here.

**Alternatives considered**: Assume package versions and file paths from earlier
project context. Rejected because those details can drift between checkouts and would
not be evidence about the active tree.

## Traccar tracking SDK

**Decision**: Use the official `traccar_client_sdk` Flutter package for device
tracking/reporting, and keep account/profile REST operations in the app's authenticated
Traccar API client. The SDK supports Android and iOS; its published Flutter guide lists
Android API 24+ and iOS 15+ as minimums. The package listing showed release 1.0.11 at
research time. Pin a compatible version when the Flutter project is restored.

**Rationale**: The Flutter package is the platform wrapper for Traccar Client's
background location reporting. It is not a general account/profile REST client. The
constitution requires SDK-based tracking and authenticated documented server APIs for
server-managed data.

**Alternatives considered**: Build a parallel location uploader or use the tracking
SDK as the user/account API. Rejected because that duplicates tracking behavior or
confuses distinct SDK and REST responsibilities.

Sources: [Traccar Flutter SDK guide](https://www.traccar.org/traccar-client-sdk-flutter/),
[package listing](https://pub.dev/packages/traccar_client_sdk),
[official SDK repository](https://github.com/traccar/traccar-client-sdk).

## Profile data contract

**Decision**: Save display-name edits through the authenticated Traccar user update
API. Upload the selected profile image to the authenticated Traccar device-image route
for the signed-in user's own device, then save the returned filename in that device's
`deviceImage` attribute. Load the image from the server-backed device media route.
Treat the server response as committed state; on failure, retain the previous image and
show a recoverable error. Reset removes local credentials/session state but does not
delete the uploaded image or modify the device record.

**Rationale**: The existing Trakkar behavior stores profile pictures as server-managed
device images, so the same image is shared across app surfaces and survives a local
reset. The image belongs to the signed-in user's device, not a local-only profile file.

**Alternatives considered**: Keep the image only in app storage or invent a user-avatar
field. Neither matches the existing device-image upload behavior.

References: authenticated `POST /api/devices/{deviceId}/image`, followed by
`PUT /api/devices/{deviceId}` to save `attributes.deviceImage`; fetch through the
server's device media route.

## Theme persistence

**Decision**: Model the selection as `system`, `light`, or `dark`; persist the enum
locally and map it to Flutter's `ThemeMode.system`, `ThemeMode.light`, and
`ThemeMode.dark` at the application shell.

**Rationale**: Flutter's `MaterialApp.themeMode` supports the requested three-way
selection and system-following behavior directly.

**Alternatives considered**: Persist only a boolean dark-mode flag. Rejected because
it cannot represent system-following mode.

Source: [Flutter `ThemeMode` API](https://api.flutter.dev/flutter/material/MaterialApp/themeMode.html).

## Map appearance preference

**Decision**: Keep the satellite-switch threshold in the same local Settings
preferences as theme selection. Use zoom level 19 for a new installation and restore
19 after confirmed app reset. Feature 002 consumes this shared preference; it remains
separate from the initial map camera fit.

**Rationale**: The threshold controls a map display choice, is explicitly user
configurable, and does not require a server change or affect account data.

## Reset semantics and SDK configuration

**Decision**: After confirmation, stop SDK tracking, clear only the app's saved
configuration and session, and clear the SDK's persisted connection configuration via
a narrow supported SDK extension/bridge if required. Preserve the SDK's queued
position database and all other user files. Return to first-run setup only after
cleanup succeeds; on partial failure, remain in a recoverable reset state and report
the failure.

**Rationale**: The SDK documentation describes persisted configuration surviving
`stop()` and `sharedTracker()` restoring that configuration. The documented wrapper
operations include setting config, start/stop, and related tracker controls, but do
not provide a clear-config operation. Its buffered-location queue is stored separately
in SQLite. A whole-app storage wipe would violate the user's reset boundary and could
delete queued position data. A small bridge must therefore clear only SDK connection
configuration and prove that the queue remains intact.

**Alternatives considered**: Wipe app data, clear SDK files/database wholesale, or
leave the SDK endpoint/config active after the app appears reset. Rejected because
these respectively delete out-of-scope user data or fail to clear the requested local
configuration. Do not route preserved queued positions to a newly configured endpoint
unless SDK behavior and explicit user intent make that safe.

Sources: [Traccar Client SDK documentation](https://www.traccar.org/traccar-client-sdk/),
[Flutter SDK wrapper](https://github.com/traccar/traccar-client-sdk/tree/main/flutter).

## Cross-platform build requirements

**Decision**: Build Android and iOS from the Flutter app using their supported native
toolchains. Android can be built on supported Flutter host systems with Android SDK
tools. iOS compilation requires macOS with Xcode; Flutter's iOS setup also calls for
CocoaPods when plugins use native code.

**Rationale**: The Traccar plugin includes native platform integration. A Dart-only
analysis cannot prove plugin compilation, permission wiring, or platform packaging.

**Alternatives considered**: Claim cross-platform compilation based only on `flutter
analyze`. Rejected because it does not compile the iOS/Android host applications.

Sources: [Flutter Android setup](https://docs.flutter.dev/platform-integration/android/setup),
[Flutter iOS setup](https://docs.flutter.dev/platform-integration/ios/setup),
[Android deployment](https://docs.flutter.dev/deployment/android),
[iOS deployment](https://docs.flutter.dev/deployment/ios).
