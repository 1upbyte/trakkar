# Phase 0 Research: Map Home

## Location and identity data

**Decision**: Build map entries from server-authorized Traccar devices and their latest
positions; retain the app's person/profile mapping where available. Use the server's
latest position update path (prefer its supported live update channel) rather than
starting another location-reporting loop. Read battery from configured device
attributes and show unknown if absent.

**Rationale**: Traccar is authoritative for shared devices and positions, while battery
is not guaranteed as a universal field. A device may not be a person or have a portrait,
so the existing app domain mapping must be preserved when app source returns.

**Alternatives considered**: Invent client-owned people/position records or assume every
device has battery/profile fields. Rejected because they can contradict server state or
present fabricated information.

Sources: [Traccar API reference](https://www.traccar.org/api-reference),
[Traccar API usage guidance](https://www.traccar.org/traccar-api/),
[OpenAPI contract](https://www.traccar.org/api-reference/openapi.yaml).

## Map rendering and layers

**Decision**: Preserve the existing map-provider integration: OpenFreeMap supplies the
standard map styles and MapTiler `satellite-v4` supplies satellite imagery. Read the
MapTiler key from `attributes.trakkarMapTilerKey` in the authenticated `GET /api/server`
response; keep it in memory and do not embed it or change the Traccar server. Default
the configurable satellite-switch threshold to zoom 19, separately from launch
framing. Use a local tile cache with 90-day freshness and a 512 MB limit; remove the
`key` query parameter from cache identity. `flutter_map` remains a candidate renderer,
subject to compatibility review against the restored app.

**Rationale**: The existing deployment provides the key through its authenticated
server configuration, so the mobile app can preserve the current server integration
without a new endpoint or embedded key. The cache policy limits disk use and avoids
making cached tile identity depend on key rotation. If the key is absent, standard map
styles remain usable and satellite imagery is reported unavailable.

**Alternatives considered**: Embed a provider key, make satellite imagery depend on a
new server endpoint, or silently switch to an undocumented imagery source. Rejected
because they change the existing integration or conflict with project constraints.

Sources: [flutter_map API](https://pub.dev/packages/flutter_map),
[Traccar server API](https://www.traccar.org/api-reference/openapi.yaml),
[Traccar map layers](https://www.traccar.org/map-layers/). Provider names, server
attribute and cache values reflect the prior app implementation recorded in project
history; this planning checkout contains no Flutter source to verify them against.

## Framing, clusters and labels

**Decision**: Compute a deterministic initial camera fit for known locations, with
explicit empty/single/multiple-location behavior and an outward framing cap at the
spec's approximately two-mile extent. Cluster only when markers would crowd; group
rendering must keep each member's circular image/initial individually visible and
selectable (for example compact sub-markers or an expansion interaction), rather than
replacing them with a count-only bubble. Apply area-aware label decluttering using
saved-place geometry.

**Rationale**: Standard count-only clustering cannot satisfy individual visibility and
selection requirements. Saved-place geometry and report times provide better context
than generic points alone.

**Alternatives considered**: Fixed world zoom, simple count bubble, or a global label
zoom cutoff. Rejected because they hide people or make labels unreadable/inconsistent
with area size.

## Detail panel and address

**Decision**: Capture camera center/zoom immediately before person selection; Back closes
the sheet and restores that snapshot. Prefer containing saved-place name, then request
reverse geocoding through the existing authenticated `GET /api/server/geocode` service,
then show coordinates. Surface age and unknown battery explicitly. Do not call a
third-party geocoder from the app or place provider credentials on the device.

**Rationale**: It matches shared Map/People selection semantics and keeps geocoding
credentials and provider calls on the server.

Source: [Traccar reverse geocoding](https://www.traccar.org/reverse-geocoding/).
