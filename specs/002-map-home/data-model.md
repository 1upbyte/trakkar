# Data Model: Map Home

## PersonMapEntry

Projection of an authorized person/device used by the map.

| Field | Type | Rules |
|---|---|---|
| `personId` | stable app/server ID | Identifies selectable person. |
| `deviceId` | Traccar ID | Identifies source device when mapping exists. |
| `displayName` | string | Prefer current profile/device name. |
| `imageRef` | image reference or null | Use portrait when available; otherwise initials. |
| `latestPosition` | Position or null | Latest server-reported position; null means no marker. |
| `batteryLevel` | number or unknown | Decode supported device attribute; validate range if present. |

## Position

| Field | Type | Rules |
|---|---|---|
| `latitude`, `longitude` | finite numbers | Validate legal coordinate ranges. |
| `fixTime` | timestamp or unavailable | Used with receipt/update time to assess freshness. |
| `address` | string or null | Prefer server-provided value; otherwise coordinates. |
| `staleness` | fresh, stale, unknown | Never label a stale position as current. |

## MapCameraSnapshot

Contains map center, zoom, and applicable rotation immediately before a person is
selected. One active snapshot is associated with the open detail sheet; restore and
clear it when Back closes that sheet.

## PeopleGroup

Set of nearby PersonMapEntry markers clustered by current screen/map distance. Every
member remains individually represented and selectable; group expansion/scaling must
not crop portrait content.

## SavedPlaceLabel

Named point/area with geometry from feature 004. Place containment may supply the
person's readable location; label visibility depends on area size, zoom, and collisions.

## MapPreferences

| Field | Type | Rules |
|---|---|---|
| `satelliteThresholdZoom` | valid map zoom level | Persisted user preference; new installations default to 19. It is independent of initial people-fit framing. |

## MapTileCachePolicy

| Field | Type | Rules |
|---|---|---|
| `freshness` | duration | Reuse cached tiles for up to 90 days. |
| `maximumSize` | bytes | Limit local map tile cache to 512 MB. |
| `cacheIdentity` | request identity | Exclude the MapTiler `key` query parameter so cache entries survive key rotation. |

The MapTiler key is read from authenticated server configuration and kept in memory;
it is not part of persisted map preferences or tile cache identity. Reverse geocoding
is performed by the authenticated Traccar server service.
