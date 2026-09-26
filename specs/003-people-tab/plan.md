# Implementation Plan: People Tab and Map Navigation

**Branch**: `003-people-tab` | **Date**: 2026-09-24 | **Spec**: [spec.md](spec.md)

**Input**: `specs/003-people-tab/spec.md`

## Summary

Add People as the second bottom tab, showing every server-authorized person with name,
portrait/initial, and readable last-known location. Selecting a located person invokes
the same Map selection action as tapping their marker; tab transitions retain both
map-camera and list-scroll context. Consume the shared Traccar people/position state
rather than creating a second data or tracking path.

## Technical Context

**Language/Version**: Dart with the Flutter app's SDK constraint `^3.13.2`.

**Primary Dependencies**: Flutter; shared authenticated Traccar API/live-update layer;
shared profile and saved-place repositories; persistent tab shell (e.g. `IndexedStack`)
with coordinated transition.

**Storage**: Server-backed devices and positions; transient/in-memory list scroll and
map camera state while app navigation is alive.

**Testing**: Flutter widget/unit coverage for completeness, missing/stale data, shared
selection, Back restoration and retained tab state; Android debug and iOS simulator
builds completed.

**Target Platform**: Flutter Android and iOS; SDK tracking requirements remain API
24+ Android and iOS 15+.

**Project Type**: Flutter mobile app.

**Performance Goals**: Tab changes have no blank intermediate frame; list and map state
remain responsive and no redundant high-frequency polling is introduced.

**Constraints**: Only display people authorized by Traccar. Label stale positions, do
not fabricate locations, and keep precise location data out of logs. The image/name
mapping follows shared profile state and server contracts.

**Scale/Scope**: One user-visible collection of all authorized people/devices and their
latest available locations, in the second bottom tab.

## Constitution Check

| Principle | Plan response | Gate |
|---|---|---|
| Server-authoritative integration | Reuse authenticated Traccar devices/positions and existing update channel. | PASS |
| Privacy/data minimization | Render only authorized people; no location-history logging. | PASS |
| Battery-aware tracking | Read shared positions; no duplicate location engine or aggressive polling. | PASS |
| Clear app experience | Explicit missing/stale states and same person detail action from Map and People. | PASS |
| Verifiable changes | Focused widget/data tests and both platform build checks documented; no source tree here. | PASS WITH VALIDATION LIMIT |

## Dependencies and project structure

Depends on 001 authenticated setup, 002 shared Map state/person-selection flow, 004
saved-place labels, and 005 shared profile/server session presentation.

Proposed Flutter locations (not present in this checkout):

```text
lib/features/people/     # list view and row state
lib/app/                  # persistent bottom-tab shell and selection routing
lib/services/             # shared Traccar data feeds
test/                      # widget and state tests
```

**Structure Decision**: Keep Map and People views mounted in one app shell so their
state survives tab changes; animate the retained view transition rather than replacing
and recreating feature state.
