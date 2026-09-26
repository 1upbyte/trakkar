# Quickstart Validation: Map Home

The current checkout has no Flutter app tree; run these from the restored Flutter root.

```sh
flutter pub get
flutter analyze
flutter test
flutter build apk --debug
flutter build ios --simulator
```

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
