# Phase 0 Research: Places Tab

## Persistence and geometry

**Decision**: Represent saved places as Traccar geofences, using authenticated
`GET/POST /geofences` and `DELETE /geofences/{id}`; send `name` and WKT `area` per the
published contract. Manual area creation uses a polygon draft. Only commit UI list/map
changes after server success; roll back optimistic state on failure.

**Rationale**: The Traccar API is server-authoritative and its geofence schema supports
named areas expressed in WKT. This preserves consistency across map, People, and Places.

**Alternatives considered**: Store place boundaries only on-device or model every place
as a device. Rejected because the former is not shared/server-authoritative and the
latter misuses the API.

Sources: [Traccar API reference](https://www.traccar.org/api-reference),
[OpenAPI contract](https://www.traccar.org/api-reference/openapi.yaml),
[Traccar geofences](https://www.traccar.org/geofences/).

## Auto building footprints

**Decision**: Read building footprints from the `building` source layer in the
OpenFreeMap vector style already loaded for the base map. Query only vector tiles
intersecting the visible map bounds, require zoom 16 or closer for selection, and reuse
the map's configured tile provider and cache. Parse the vector-tile geometry locally,
highlight candidate outlines, and retain OpenStreetMap attribution. If tiles or usable
outlines are unavailable, offer Manual mode. Do not add an Overpass request or a
separate building-data provider.

**Rationale**: The building outlines share the same source and network/cache path as
the displayed map. This avoids a separate geospatial service, provider configuration,
or per-building lookup request.

**Alternatives considered**: Query public Overpass instances or add a separate
building-footprint service. Not selected because the existing map vector tiles already
provide the required building layer.

## Validation and deletion

**Decision**: Keep drafts transient until Save; require a non-empty trimmed name and
valid closed geographic polygon with at least three distinct non-collinear vertices.
Confirm deletion with the place name; cancel is mutation-free. Show explicit failures
and retain server-consistent data.

**Rationale**: It prevents invalid geometry and satisfies the required preview,
confirmation and failure semantics.

**Alternatives considered**: Save every corner edit remotely or delete optimistically
before confirmation. Rejected because both risk partial server state and undermine
confirmation semantics.
