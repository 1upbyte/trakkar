# Implementation Plan: QR Login and First-Run Setup

**Branch**: `001-qr-login` | **Date**: 2026-09-25 | **Spec**: [spec.md](spec.md)

**Input**: `specs/001-qr-login/spec.md`

## Summary

Build the first-run choice between scanning an existing credential-bearing QR code and
entering the same details manually. Both paths feed one authentication flow.
Decode the complete standard Base64 UTF-8 payload once, then parse exactly
`user;password;clienturl;managerurl` and immediately submit valid scans without a
confirmation prompt. Manual details submit when the user taps Submit. Use the restored
app's existing Traccar sign-in/session behavior,
and keep payloads and secrets out of logs and diagnostics. Since semicolon is the
delimiter and there is no escaping, reject QR values containing semicolons. Android/iOS
camera setup and Flutter host builds are part of the feature.

## Technical Context

**Language/Version**: Dart with the Flutter stable version selected by the restored app;
current checkout has no app manifest or source to identify the pin.

**Primary Dependencies**: Flutter; a maintained QR camera scanner such as
`mobile_scanner`; existing authenticated Traccar API/session client; secure storage for
session material. Confirm compatible package versions when app source is restored.

**Storage**: After successful authentication, store username, password, both service
URLs, and session data in platform secure storage for future authentication. Keep raw QR
text and unverified credentials transient; never persist raw QR text or an unsuccessful
login draft.

**Testing**: Parser/validation unit tests with producer-approved fixtures; widget tests
for choice, immediate QR authentication, permission/error/retry and manual flow; auth contract tests and
Android/iOS builds. No Flutter/test tree exists here to run them.

**Target Platform**: Flutter Android and iOS; both use app identifier
`com.oneupbyte.trakkar`. iOS camera use requires `NSCameraUsageDescription`; Android
requires runtime camera permission through the scanner plugin/host setup.

**Project Type**: Flutter mobile app.

**Performance Goals**: Decode a scan promptly on-device; submit for sign-in immediately
after successful local parsing.

**Constraints**: Base64 is reversible encoding, not encryption. Show a non-blocking
privacy notice on the setup-choice screen before scanning. Treat both raw QR text
and decoded values as secrets. Do not locally validate URL schemes, host syntax, or
embedded URL credentials; permit HTTP without warning and do not restrict redirects by
origin. Never expose credentials or URL user-info in logs, diagnostics, or errors. The
transport determines whether it can use a configured URL. Reuse current
Traccar authentication rather than inventing another auth scheme.

**Scale/Scope**: First-run setup for one app installation; scan codes made by the
existing external workflow, with manual entry as an equivalent fallback.

## Constitution Check

| Principle | Plan response | Gate |
|---|---|---|
| Server-authoritative integration | Reuse authenticated Traccar session/API and SDK setup after validation. | PASS |
| Privacy/data minimization | Credentials remain memory-only until authentication succeeds, then persist in platform secure storage for future authentication; raw QR text is never persisted or logged. | PASS |
| Battery-aware tracking | Do not start tracking until setup/auth completes and existing user choice/permission allows it. | PASS |
| Verifiable changes | Producer fixtures, invalid-payload, auth distinction and platform camera checks are documented. | PASS WITH VALIDATION LIMIT |
| External compatibility | Use the user-specified ordered semicolon grammar and one Base64 encoding over the whole UTF-8 string; validate against golden fixtures. | PASS |

## Dependencies and project structure

Foundation for features 002–005: successful setup supplies the authenticated session,
service endpoints and secure configuration used by all later tabs.

Proposed structure (not present in this checkout):

```text
lib/features/setup/       # first-run choice, QR scanner, manual form
lib/services/auth/        # shared setup validation and existing Traccar session flow
lib/models/               # login draft and setup attempt
android/ ios/             # shared app identifier, camera permission, and Flutter host configuration
test/                      # parser, widget, and auth behavior coverage
```

**Structure Decision**: Keep QR parsing, manual input, and server authentication behind
one setup boundary so both entry paths have identical validation and failure behavior.
