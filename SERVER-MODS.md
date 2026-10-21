# Trakkar server compatibility and extension contract

## Summary

Trakkar does **not** require a fork of the official Traccar server for profile
pictures or shared friendly place names.

The official server has no user-profile/avatar field and no dedicated
"friendly place" model. Trakkar maps those concepts onto two official server
features instead:

- A person's profile picture is the image of their Traccar **device**. This is
  the correct scope for Trakkar because one app profile is represented by one
  device whose `uniqueId` is the Trakkar username.
- A friendly place is an official circular **geofence** with a Trakkar marker
  in its attributes.

This keeps the server unmodified and makes both records visible to every
Trakkar client logged in as the same manager user (or otherwise granted access
to those devices/geofences). The phone keeps a cache for offline rendering, but
the Traccar server is the source of truth.

Official references:

- Traccar OpenAPI specification: <https://github.com/traccar/traccar/blob/master/openapi.yaml>
- Device image resource implementation: <https://github.com/traccar/traccar/blob/master/src/main/java/org/traccar/api/resource/DeviceResource.java>
- Official web UI device-image flow: <https://github.com/traccar/traccar-web/blob/master/src/settings/DevicePage.jsx>
- Geofence documentation: <https://www.traccar.org/geofences/>
- Geofence server model: <https://github.com/traccar/traccar/blob/master/src/main/java/org/traccar/model/Geofence.java>

## Authentication and URL convention

Trakkar signs in with `POST /api/session` using form fields `email` and
`password`. All requests below send the returned `JSESSIONID` cookie. Examples
assume a manager base URL of `https://manager.example.com`; installations under
a path prefix work as well.

Production deployments should use HTTPS. The client endpoint used by the
official Traccar Client SDK is separate from this manager REST endpoint.

## Server-side API keys

Third-party provider keys are server configuration, not per-phone settings.

- Configure reverse geocoding through Traccar's normal server geocoder
  settings. Trakkar calls only `GET /api/server/geocode`; it never receives or
  stores that provider's key.
- Store the MapTiler key in the Traccar server object's custom attributes under
  `trakkarMapTilerKey`. An administrator can update the Server record through
  the Traccar UI or `PUT /api/server`, preserving all other server fields and
  attributes. Trakkar reads this value from `GET /api/server` after signing in
  and keeps it in memory only.

MapTiler tiles are requested directly by the phone, so this key is not a
server-side secret even though the server is its source of truth. Restrict the
key by allowed app/origin and API scope in MapTiler. A deployment that requires
the key never to reach clients must add an authenticated tile-proxy endpoint
and configure equivalent caching there.

## Profile pictures using official device images

### Data ownership

Each Trakkar person is a Traccar device:

- `device.name`: the person's display/first name
- `device.uniqueId`: the username entered during onboarding and the identifier
  configured in the official Traccar Client SDK
- `device.attributes.deviceImage`: the server-generated image filename

There is no account-level user avatar in the official model. Consequently, a
single Traccar user managing several people sees one picture per device/person.

### Upload protocol

1. Select and resize an image on the phone.
2. Send the raw image bytes to:

   ```http
   POST /api/devices/{deviceId}/image
   Cookie: JSESSIONID=...
   Content-Type: image/jpeg

   <raw image bytes>
   ```

3. The official endpoint returns a generated filename such as `device.jpg` or
   `device.png` in the response body.
4. Preserve every existing device property and attribute, add/update
   `attributes.deviceImage`, and save the device:

   ```http
   PUT /api/devices/{deviceId}
   Cookie: JSESSIONID=...
   Content-Type: application/json

   {
     "id": 12,
     "name": "Pablo",
     "uniqueId": "pablo",
     "attributes": {
       "deviceImage": "device.jpg"
     }
   }
   ```

The current official server accepts JPEG, PNG, GIF, and WebP, and enforces a
500,000-byte upload limit. Trakkar enforces the same rules before upload and
does not upload SVG.

### Download protocol

After fetching devices with `GET /api/devices`, a client that finds a non-empty
`attributes.deviceImage` downloads:

```http
GET /api/media/{urlEncodedDeviceUniqueId}/{urlEncodedDeviceImageFilename}
Cookie: JSESSIONID=...
```

Trakkar renders initials in a circle when the attribute is absent, the media
returns 404, the account lacks access, or the image cannot be decoded. Device
updates received over `/api/socket` trigger a picture refresh. A manual refresh
also reloads the device list and missing images.

### Client-side safety rules

The current app only constructs media paths for device IDs and filenames made
of letters, numbers, `.`, `_`, and `-`. Onboarding device IDs must begin with a
letter or number, be no longer than 64 characters, and cannot contain `..`.
These checks are defense in depth; a server must still generate filenames and
must never concatenate untrusted path input without normalizing and verifying
the final storage path.

## Friendly names using official geofences

### Canonical representation

A Trakkar friendly place is a circular Traccar geofence with this payload:

```json
{
  "id": 0,
  "name": "Home",
  "description": "Friendly place created by Trakkar",
  "area": "CIRCLE (40.7128 -74.006, 150.0)",
  "calendarId": 0,
  "attributes": {
    "trakkarNamedPlace": true,
    "trakkarSchemaVersion": 3
  }
}
```

The circle syntax is `CIRCLE (latitude longitude, radiusMeters)`. Notice that
latitude comes first; this follows Traccar's geofence model rather than common
GeoJSON longitude-first ordering.

The marker attribute is mandatory. Trakkar ignores ordinary geofences so a
fleet administrator's existing zones are not shown as friendly address names.
Unknown future schema versions should be preserved by writers and ignored or
handled conservatively by older clients.

### CRUD and account sharing

- List: `GET /api/geofences`
- Create: `POST /api/geofences` with the JSON above
- Delete: `DELETE /api/geofences/{id}`
- A future rename/radius edit can use `PUT /api/geofences/{id}`, preserving all
  unknown fields and attributes.

An unmodified server associates a newly created geofence with the creating
user. Every Trakkar installation signed in as that user will load it. Standard
Traccar permissions can expose it to other users as usual.

Named places provide shared location names. Trakkar does not create departure
notifications or device-geofence links. Notifications generated by older app
versions can be removed in Traccar under Notifications.

### Address resolution

For a position, Trakkar evaluates all tagged circles available to the user. It
calculates surface distance from the circle center and chooses the nearest
circle that contains the position. Resolution priority is:

1. Shared Trakkar friendly place name
2. Address already attached to the Traccar position
3. Configured reverse-geocoding provider

The current UI accepts radii from 10 through 10,000 meters and defaults to 150
meters. A server implementation should validate finite coordinates, latitude
`[-90, 90]`, longitude `[-180, 180]`, radius bounds, and a reasonable UTF-8 name
length (for example 1-128 Unicode scalar values).

### Sync, offline cache, and migration

At startup and manual refresh the app fetches devices, positions, and geofences.
The returned tagged geofences replace the cached named-place list. A newly
created or deleted place updates the server first and the cache only after the
server succeeds.

Earlier Trakkar builds stored places only in `SharedPreferences`. Records that
do not have `serverBacked: true` are migrated on the first successful manager
refresh by creating tagged geofences. Before creating one, the app checks for a
server record with the same name and center (within `0.000001` degrees) to
reduce duplicates. After migration, the cache stores the server geofence ID.

The standard socket primarily supplies device and position changes. Another
phone sees a friendly-place change on its next refresh or app launch. If
instant cross-client place editing is later required, implement the websocket
event described below.

## Optional first-class server implementation

The compatibility mapping above is the supported implementation today. A
custom server can introduce first-class resources while retaining compatibility.
The following contract is detailed enough to implement them without depending
on geofence or device-image internals.

### Suggested database schema

```sql
CREATE TABLE tc_trakkar_profile (
    device_id       BIGINT PRIMARY KEY REFERENCES tc_devices(id) ON DELETE CASCADE,
    media_key       VARCHAR(255) NOT NULL,
    content_type    VARCHAR(32) NOT NULL,
    byte_length     INTEGER NOT NULL,
    content_sha256  CHAR(64) NOT NULL,
    updated_at      TIMESTAMP NOT NULL,
    updated_by      BIGINT NOT NULL REFERENCES tc_users(id)
);

CREATE TABLE tc_trakkar_place (
    id              BIGINT GENERATED BY DEFAULT AS IDENTITY PRIMARY KEY,
    owner_user_id   BIGINT NOT NULL REFERENCES tc_users(id) ON DELETE CASCADE,
    name            VARCHAR(128) NOT NULL,
    latitude        DOUBLE PRECISION NOT NULL,
    longitude       DOUBLE PRECISION NOT NULL,
    radius_meters   DOUBLE PRECISION NOT NULL,
    version         INTEGER NOT NULL DEFAULT 1,
    created_at      TIMESTAMP NOT NULL,
    updated_at      TIMESTAMP NOT NULL,
    created_by      BIGINT NOT NULL REFERENCES tc_users(id),
    updated_by      BIGINT NOT NULL REFERENCES tc_users(id)
);

CREATE INDEX tc_trakkar_place_owner_idx
    ON tc_trakkar_place(owner_user_id);
```

Use the same database naming/identity conventions as the target Traccar
version. If places need normal Traccar permission sharing rather than strict
owner-account sharing, add a permission relationship equivalent to other
Traccar managed objects.

### Suggested first-class REST API

All endpoints require the normal authenticated Traccar session and object-level
permission checks.

```text
GET    /api/trakkar/devices/{deviceId}/profile-image
PUT    /api/trakkar/devices/{deviceId}/profile-image
DELETE /api/trakkar/devices/{deviceId}/profile-image

GET    /api/trakkar/places
POST   /api/trakkar/places
GET    /api/trakkar/places/{id}
PUT    /api/trakkar/places/{id}
DELETE /api/trakkar/places/{id}
```

`PUT profile-image` accepts raw JPEG, PNG, GIF, or WebP and returns:

```json
{
  "deviceId": 12,
  "contentType": "image/jpeg",
  "byteLength": 84321,
  "etag": "sha256:...",
  "updatedAt": "2026-09-01T12:00:00Z"
}
```

`GET profile-image` returns bytes with the correct `Content-Type`, a strong
`ETag`, `X-Content-Type-Options: nosniff`, and private cache controls. Support
`If-None-Match` so map refreshes do not repeatedly transfer unchanged images.

Place request/response JSON:

```json
{
  "id": 91,
  "name": "Home",
  "latitude": 40.7128,
  "longitude": -74.006,
  "radiusMeters": 150.0,
  "version": 3,
  "updatedAt": "2026-09-01T12:00:00Z"
}
```

Use optimistic concurrency (`If-Match`, an ETag, or the `version` field) for
updates and return 409/412 for stale writes. Return stable JSON error codes and
short user-safe messages; do not expose Java stack traces to mobile clients.

### Suggested websocket events

Broadcast only after the transaction commits and only to sessions that may
read the object:

```json
{"trakkarPlaces":[{"operation":"upsert","place":{...}}]}
{"trakkarPlaces":[{"operation":"delete","id":91}]}
{"trakkarProfiles":[{"deviceId":12,"etag":"sha256:..."}]}
```

Clients should still reconcile with REST after reconnect because socket events
can be missed.

### Media security requirements

- Authorize access to the device before upload and download.
- Generate the storage key on the server; never use a client path verbatim.
- Resolve and verify the final canonical path remains inside the media root.
- Reject SVG and active formats. Verify file signatures instead of trusting
  only `Content-Type` or extensions.
- Prefer decoding and re-encoding uploads to remove metadata and malformed
  payloads. Enforce decoded pixel/dimension limits as well as byte limits.
- Set `X-Content-Type-Options: nosniff` and an explicit raster content type.
- Apply upload rate limits and record the authenticated actor in an audit log.
- Delete or garbage-collect the old blob only after the database update commits.

These rules are particularly important for any implementation modeled after a
media endpoint. Review current Traccar security advisories before deploying a
fork: <https://github.com/traccar/traccar/security/advisories>.

## Migrating between compatibility and first-class resources

To migrate to custom tables:

1. For each accessible device with `attributes.deviceImage`, copy the media
   bytes into the profile store and retain the device ID as the key.
2. For each geofence where `attributes.trakkarNamedPlace == true`, parse its
   circle and insert a place owned by the geofence's user.
3. Run both readers during a transition period. Prefer the first-class record
   and fall back to the official representation.
4. Dual-write until all deployed clients understand the new endpoints.
5. Stop dual-write only after telemetry shows no old clients. Keep the old
   records for a rollback window before removing them.

The reverse migration performs the opposite transformation and is lossless for
the fields used by the current app.

## Compatibility test checklist

- Sign in as a standard non-admin user.
- Upload each supported raster format below 500 KB and reject an oversized file.
- Verify another phone on the same manager account displays the device picture.
- Verify a user without device access cannot fetch that picture.
- Create Home from a person's bottom sheet and verify a tagged circle appears
  in the official Traccar geofence list.
- Verify ordinary geofences are not treated as friendly names.
- Verify the nearest containing friendly place takes priority over reverse
  geocoding on another phone after refresh.
- Delete the place and verify it disappears after refresh on all clients.
- Test names containing Unicode and JSON-significant characters.
- Test malformed circle data, missing media, expired sessions, 401, 403, 404,
  413, 429, and 5xx responses without exposing response bodies or stack traces.
