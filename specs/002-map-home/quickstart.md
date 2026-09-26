# Quickstart Validation: Map Home

Run these from the repository root. The Flutter app lives in the root project.

```sh
flutter pub get
flutter analyze
flutter test
flutter build apk --debug
flutter build ios --simulator
```

## Validation results (2026-09-26)

- `flutter analyze`: passed with no issues.
- `flutter test`: all 47 tests passed, including map camera fit, people markers and
  clusters, person details and selection state, saved-place labels, authenticated
  Traccar data, server geocoding, map retry behavior, tile-cache policy, and the
  existing setup flows.
- `flutter build apk --debug`: passed. Flutter reports a future Kotlin Gradle Plugin
  compatibility warning from `traccar_client_sdk`.
- `flutter build ios --simulator`: passed.
- Physical-device permission behavior, live Traccar authorization and updates, provider
  tile attribution, and real MapTiler-key availability still need manual verification.

The iOS command requires macOS/Xcode and CocoaPods. Expected focused coverage: empty,
single, inside-cap and outside-cap fit; circular portrait/initial rendering; crowded
member visibility and selection; absent/stale position and battery; saved-place label
priority/decluttering; new-install satellite threshold 19 and preference persistence;
MapTiler key loading from authenticated `/api/server`; `satellite-v4` switching and
standard-map fallback when the key is absent; tile reuse up to 90 days within 512 MB
with cache identity independent of the key; server reverse geocoding and saved-place /
coordinate fallback; selection followed by exact camera restoration on Back. On both
platforms, manually verify real server authorization, tile attribution, loading/error
states, and location privacy. See the [UI contract](contracts/map-ui.md) and
[data model](data-model.md).
