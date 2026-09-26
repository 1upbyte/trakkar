# Implementation Plan: Map Home and People Overview

**Branch**: `002-map-home` | **Date**: 2026-09-24 | **Spec**: [spec.md](spec.md)

**Input**: `specs/002-map-home/spec.md`

## Summary

Make the Map the signed-in landing tab. Render each located person as a circular
portrait/initial marker, preserve individual identities in crowded groups, cap the
automatic overview at the specified roughly two-mile extent, and open a person detail
sheet with camera restoration on Back. Reuse authenticated Traccar device/position
data, saved places from feature 004, and app profile identity; use MapTiler
`satellite-v4` imagery with its key from the existing authenticated `/api/server`
configuration, switch at the persisted zoom threshold (default 19), cache tiles for
90 days up to 512 MB without key-dependent cache identity, and reverse-geocode through
the existing authenticated server geocoder.

## Technical Context

**Language/Version**: Dart with the Flutter stable release selected by the restored app;
no `pubspec.yaml` or Dart sources exist in this checkout, so the exact pin is unknown.

**Primary Dependencies**: Flutter; official `traccar_client_sdk` for location tracking;
authenticated Traccar REST/WebSocket client for shared device and position reads;
recommended `flutter_map` renderer if it matches the restored app's architecture.

**Storage**: Server-authoritative device/position/place and geocoding data; in-memory
MapTiler key read from authenticated server configuration; local persisted satellite
zoom threshold (default 19) and bounded tile cache (90-day freshness, 512 MB maximum);
transient pre-selection camera snapshot and view state.

**Testing**: Flutter unit/widget tests for fit policy, stale/missing data, clusters,
selection and camera restoration; platform compilation checks. No source/test tree is
present to run them in this checkout.

**Target Platform**: Flutter Android and iOS using the Traccar SDK's supported minimums
(Android API 24+, iOS 15+); native builds require their respective toolchains.

**Project Type**: Flutter mobile app.

**Performance Goals**: Keep map gestures and tab interactions responsive; avoid
unbounded position polling and map/provider requests.

**Constraints**: The Traccar server is authoritative. Use SDK tracking, authenticated
position/device reads, and the existing server-provided MapTiler key and geocoding
service. Do not add a server endpoint/code change, Google Maps SDK, embedded provider
key, or direct third-party geocoder call. Cache identity excludes the MapTiler key.
Battery is device-attribute data and may be unavailable. Preserve map context before
selection and report stale status honestly.

**Scale/Scope**: Authorized people/devices, most recent positions, saved place labels,
and one user's map preferences and camera state.

## Constitution Check

| Principle | Plan response | Gate |
|---|---|---|
| Server-authoritative integration | Read authenticated Traccar devices/positions and reuse the tracking SDK. | PASS |
| Privacy/data minimization | Render only authorized positions; avoid logging coordinates/history; geocode through server when available. | PASS |
| Battery-aware tracking | Do not add a parallel tracker or aggressive polling; use the existing SDK/session update path. | PASS |
| Clear, accessible map | Distinguishable identity markers, legible place labels, explicit unavailable/stale states. | PASS |
| Verifiable changes | Test fit, cluster selectability, threshold, status and Back restoration; builds pending absent source. | PASS WITH VALIDATION LIMIT |
| Map provider constraints | Read the existing MapTiler key from authenticated `/api/server`; use `satellite-v4`, standard OpenFreeMap styles, and a usable standard-map fallback if the key is absent. Keep geocoding server-side and use the bounded, key-independent tile cache. | PASS |

## Dependencies and project structure

Depends on 001 login/session setup for authenticated endpoints and 004 places for
boundaries and label names. Feature 003 reuses the same person-selection action.

Proposed Flutter structure (not present in this checkout):

```text
lib/features/map/       # map screen, camera policy, markers, details sheet
lib/models/             # person/device, position, saved-place projections
lib/services/           # Traccar API/socket and map-layer configuration adapters
android/ ios/           # Flutter host projects
test/                   # unit and widget coverage
```

**Structure Decision**: Keep the map in the shared Flutter app and use adapters for
server feeds, the existing server map/geocoding configuration, tile caching, and
rendering so missing imagery configuration has a controlled standard-map fallback.
