# Implementation Plan: Settings Tab and App Reset

**Branch**: `005-settings-tab` | **Date**: 2026-09-24 | **Spec**: [spec.md](spec.md)

**Input**: Feature specification from `specs/005-settings-tab/spec.md`

## Summary

Add Settings as the fourth bottom-navigation destination, with profile editing,
persisted System/Light/Dark theme selection and map satellite threshold (default zoom
19), a redacted summary of the active Traccar client and manager endpoints, and a
confirmed reset that clears local configuration and restores the map threshold default.
Build the client as a Flutter app for Android and iOS and use the official
Traccar Flutter Client SDK for tracking. Use authenticated Traccar REST operations for
server-managed profile fields and the signed-in user's device-image upload. Reset must
stop tracking and clear the
SDK's persisted connection configuration without deleting its queued location data or
any server-side data.

## Technical Context

**Language/Version**: Dart, version bundled with the selected Flutter stable release;
the exact SDK pin is unavailable because this checkout contains no Flutter project.
Pin it when the app scaffold is restored.

**Primary Dependencies**: Flutter; `traccar_client_sdk` (official Flutter wrapper,
verified release 1.0.11); the existing Traccar REST/API client if present; Flutter
secure storage/preferences and image selection packages already adopted by the app.
Package versions for the absent app cannot be confirmed here.

**Storage**: Secure local storage for credentials/session and server endpoints;
preferences for theme and satellite threshold (default zoom 19); profile image stored
on the Traccar server as the signed-in user's device image;
the SDK's own persistent configuration and SQLite position queue. Reset clears only
the local configuration named in the spec and must preserve unrelated user data and
queued positions.

**Testing**: Flutter unit/widget tests plus platform build checks for Android and iOS;
native tests for any SDK bridge change. No app or test tree exists in this checkout,
so validation is described in `quickstart.md` but cannot be run here.

**Target Platform**: Android API 24+ and iOS 15+ (minimums stated by the Traccar
Flutter SDK), with Flutter stable. iOS build/signing requires macOS, Xcode, and CocoaPods.

**Project Type**: Flutter mobile app with Android and iOS host projects.

**Performance Goals**: Settings interactions should update locally without blocking
the UI; profile requests and reset must show progress and actionable failures. No
special throughput target applies.

**Constraints**: Traccar server remains authoritative for shared profile/account data;
tracking uses the Traccar SDK. Never display or log passwords, tokens, or precise
location history. Reset must not delete server-side data, SDK queued positions, or
other local user data. Upload the profile picture through the Traccar device-image API
and store its returned filename in the device's `deviceImage` attribute; local reset
must leave that server image intact. The SDK persists configuration and the published
Flutter wrapper exposes no supported clear-configuration method, so clearing only
that configuration needs a narrowly scoped SDK/native bridge change that preserves
the position queue.

**Scale/Scope**: One signed-in user's settings and local configuration; changes affect
profile presentation across Map, People, Places, and Settings, plus first-run routing
after reset. The satellite threshold is shared with feature 002. No server migration is
planned.

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-checked after Phase 1 design.*

| Principle / constraint | Plan response | Gate |
|---|---|---|
| Server-authoritative Traccar integration | Use the official SDK for tracking and authenticated REST for documented server-owned profile fields. No parallel tracker or client-held map keys. | PASS |
| Location privacy and data minimization | Mask credentials and tokens in Settings; do not expose or log location data. Reset preserves queued positions and server records. | PASS |
| Battery-aware tracking | Reset asks the SDK to stop before clearing its stored connection configuration; no tracking behavior changes otherwise. | PASS |
| Clear, accessible app experience | Put Settings last in bottom navigation; expose labeled theme, map appearance, and reset controls with progress, confirmation, and errors. | PASS |
| Verifiable changes and failure handling | Plan focused tests for profile/theme persistence, reset cancellation/failure, queue preservation, and both platform builds. Source is absent, so implementation and build evidence remain pending. | PASS WITH VALIDATION LIMIT |
| Platform and API compatibility | Target SDK minimums and use documented Traccar user update contract. SDK reset requires a narrow bridge because no clear-config method is published. | PASS WITH IMPLEMENTATION RISK |

No constitution exception is requested. The SDK bridge must be reviewed to ensure it
clears only persisted connection configuration; if it cannot preserve the queued
position store, do not ship reset until the implementation is revised or the SDK
provides a supported operation.

## Project Structure

The present checkout contains only Spec Kit artifacts and no Flutter source. The
following is the proposed Flutter layout to reconcile with the actual app when its
source is restored; existing project conventions take precedence where they provide
the same boundaries.

### Documentation (this feature)

```text
specs/005-settings-tab/
├── plan.md
├── research.md
├── data-model.md
├── quickstart.md
└── contracts/
    ├── settings-ui.md
    └── traccar-api.md
```

### Proposed source code (repository root after app source is restored)

```text
lib/
├── main.dart
├── app/                 # app shell, navigation, theme, first-run routing
├── features/
│   └── settings/        # settings screen, state, and profile/theme/reset actions
├── models/              # shared profile and server configuration models
└── services/            # Traccar REST client, secure config, SDK adapter

android/                 # Flutter Android host and narrow SDK bridge if needed
ios/                     # Flutter iOS host and narrow SDK bridge if needed
test/                    # Dart unit and widget tests
```

**Structure Decision**: Single Flutter application with standard `lib/`, `android/`,
`ios/`, and `test/` directories. No separate backend is introduced. The paths are a
proposed structure, not observed directories in this checkout.
