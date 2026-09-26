# Traccar Geofence and Building Data Contract

## Traccar persistence

- List accessible geofences with authenticated `GET /geofences`.
- Create a named area with authenticated `POST /geofences`, including `name` and WKT
  `area` in the documented Geofence resource.
- Delete with authenticated `DELETE /geofences/{id}` only after named confirmation.
- Treat successful server responses as commit; on failures keep UI consistent with the
  last server state. Refresh/reconcile after uncertain network outcomes.

Reference: [Traccar API reference](https://www.traccar.org/api-reference) and
[OpenAPI document](https://www.traccar.org/api-reference/openapi.yaml).

## Building lookup

Building footprints come from the `building` source layer in the OpenFreeMap vector
style already loaded by the base map, not from the Traccar geofence API. Read tiles
intersecting the visible map bounds through the map's existing vector-tile provider and
cache, and parse their geometry locally. Keep OpenStreetMap attribution visible. No
usable outline or tile error produces a clear state and Manual fallback. Do not add an
Overpass call or a separate building-provider endpoint.
