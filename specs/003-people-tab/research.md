# Phase 0 Research: People Tab

## Shared people and position data

**Decision**: Project the authenticated user's accessible Traccar devices and latest
positions into the app's shared Person model. Keep permission filtering server-led;
prefer live updates through the existing socket/session client. Missing locations remain
in the list with an unavailable state. Stale positions include their update time.

**Rationale**: Traccar's `/positions` API returns last-known positions for accessible
devices, and its API guidance recommends WebSocket for updates. The People spec already
defines stale/missing behavior and requires all authorized people to remain findable.

**Alternatives considered**: Query separate feeds for list and map, or periodically
poll at a high frequency. Rejected because they create inconsistent views and redundant
load.

Sources: [Traccar API reference](https://www.traccar.org/api-reference),
[Traccar API usage](https://www.traccar.org/traccar-api/),
[OpenAPI document](https://www.traccar.org/api-reference/openapi.yaml).

## Tab continuity and selection

**Decision**: Keep tab children mounted in a persistent shell, using a structure such as
Flutter `IndexedStack`, then animate visibility/transition around retained Map and
People content. Route a row tap through the same selected-person action used by a map
marker, with a pre-selection camera snapshot restored on Back.

**Rationale**: Persistent children retain the map camera and list scroll position.
Replacing tab subtrees solely for an animated transition would risk losing both.

**Alternatives considered**: Push a separate person detail page or recreate tabs on
each change. Rejected because the spec requires the same map modal behavior and context
retention.

Sources: [Flutter IndexedStack](https://api.flutter.dev/flutter/widgets/IndexedStack-class.html),
[Flutter AnimatedSwitcher](https://api.flutter.dev/flutter/widgets/AnimatedSwitcher-class.html).

## Location descriptions

**Decision**: Use saved place containment first, then server-provided address, then
coordinates. Share the same description formatter with Map detail. Avoid a new
client-side reverse-geocoder.

**Rationale**: It satisfies the documented priority while keeping geocoding and exact
coordinates within existing server-backed flows.

Source: [Traccar reverse geocoding](https://www.traccar.org/reverse-geocoding/).
