# Traccar Map Data Contract

Use the existing authenticated Traccar client and server authorization:

- Read devices and latest positions through documented device/position APIs.
- Consume live updates through the existing supported server update channel when
  available; do not add an independent tracker or unbounded polling loop.
- Use the latest position timestamp and device-specific battery attributes only when
  present and valid.
- Read saved places from the shared geofence repository defined by feature 004.
- Load the MapTiler key from the existing authenticated `GET /api/server` response's
  `attributes.trakkarMapTilerKey`; use it for the `satellite-v4` tile layer. Keep it in
  memory and do not embed or log it. No server endpoint or server code change is
  required. If absent, keep the standard map usable and report satellite imagery as
  unavailable.
- Use the existing authenticated `GET /api/server/geocode` reverse-geocoding service.
  Do not call a third-party geocoder directly or ship its credentials in the app.
- Cache map tiles for up to 90 days with a 512 MB local size limit. Exclude the
  MapTiler `key` query parameter from cache identity.
- Standard map styles use the existing OpenFreeMap integration; satellite imagery
  uses MapTiler `satellite-v4`.
- Never log precise coordinates or location history.

Reference: [Traccar API reference](https://www.traccar.org/api-reference) and
[OpenAPI contract](https://www.traccar.org/api-reference/openapi.yaml).
