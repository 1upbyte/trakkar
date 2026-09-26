# Implementation Plan: Places Tab and Saved Place Management

**Branch**: `004-places-tab` | **Date**: 2026-09-24 | **Spec**: [spec.md](spec.md)

**Input**: `specs/004-places-tab/spec.md`

## Summary

Add a Places tab for server-backed saved-area browsing, named-confirmation deletion,
and Auto/Manual creation. Persist saved place boundaries as Traccar geofences using
authenticated CRUD. Auto mode previews a selected mapped building footprint from the
OpenFreeMap base-map vector tiles; Manual mode edits polygon corners. Both paths
validate the final geometry and non-empty name before save and update map labels only
after server success.

## Technical Context

**Language/Version**: Dart with Flutter stable as selected by the restored app; no
Flutter project or version pin is present in this checkout.

**Primary Dependencies**: Flutter; authenticated Traccar REST client and geofence
repository; Flutter map renderer shared with feature 002; OpenFreeMap vector tiles,
reading the `building` source layer from the same style used by the base map.

**Storage**: Traccar server stores saved geofence name and WKT area; creation draft and
selected mode are local transient state until save.

**Testing**: Geometry/unit tests, create/delete UI and API contract tests, failure
rollback tests, plus Android/iOS builds. No source tree exists to run these here.

**Target Platform**: Flutter Android and iOS; native builds use their respective
toolchains.

**Project Type**: Flutter mobile app.

**Performance Goals**: Fetch only building footprints in the active selection area;
avoid repeated identical queries and keep boundary editing responsive.

**Constraints**: Server remains authoritative for saved places. Do not embed map
secrets. Building data comes from the OpenFreeMap vector tiles already used by the base
map; do not add a separate building lookup service. Preserve required OpenStreetMap
attribution and offer Manual when building outlines are unavailable. Do not mutate
list/map state as successful until server CRUD succeeds.

**Scale/Scope**: One authorized account's existing Traccar geofences plus an unsaved
draft of one point/polygon boundary at a time.

## Constitution Check

| Principle | Plan response | Gate |
|---|---|---|
| Server-authoritative integration | Geofences use authenticated Traccar CRUD; drafts remain local until save succeeds. | PASS |
| Privacy/data minimization | Building lookup reads only the visible-area tiles already needed by the base map; avoid credential/location logging. | PASS |
| Clear, accessible map | Show preview/draft/save states distinctly; validate corners; label/shape remain legible. | PASS |
| Verifiable changes | Test geometry, fallback, confirmation, server failures and map synchronization; builds pending. | PASS WITH VALIDATION LIMIT |
| Map/provider constraints | Read the `building` source layer from the OpenFreeMap vector style already loaded by the base map; retain OpenStreetMap attribution and existing tile behavior. | PASS |

## Dependencies and project structure

Depends on 001 authentication, 002 map editing/rendering and labels, 003 location-name
resolution, and 005 session/server context.

Proposed paths (not present in this checkout):

```text
lib/features/places/   # list, add/edit flow, geometry draft
lib/models/             # SavedPlace, geometry and draft models
lib/services/           # Traccar geofence API and vector-tile building lookup
test/                   # geometry and feature tests
```

**Structure Decision**: Keep vector-tile decoding behind a narrow building lookup
service so the app can fall back to Manual mode when outlines are unavailable.
