# Data Model: Places Tab

## SavedPlace

| Field | Type | Rules |
|---|---|---|
| `id` | Traccar geofence ID | Stable server identity. |
| `name` | string | Trimmed and non-empty. Duplicate policy follows the spec: allowed. |
| `geometry` | point/circle/polygon | Existing supported shapes remain displayable; new manual creation is polygon. |
| `wktArea` | string | Server representation; parse/validate before display/edit. |
| `source` | auto, manual, existing | Creation provenance for UI/debug state; never treated as authority over server record. |

## PlaceCreationDraft

| Field | Type | Rules |
|---|---|---|
| `mode` | auto or manual | Chosen at start. |
| `candidateBuildingId` | string or null | OpenFreeMap vector-tile feature identity when available. |
| `geometry` | geographic vertices | Transient preview; does not create server data until save. |
| `name` | string | Required trimmed non-empty before save. |
| `status` | selecting, loading, editing, validating, saving, failed, canceled | Failure/cancel preserves existing saved places. |

Validation: polygon has at least three distinct non-collinear vertices; all
coordinates are finite and within geographic bounds; ring is closed/normalized for WKT.

## BuildingCandidate

OpenFreeMap vector-tile feature containing a stable source identity, outline geometry,
optional label, and source attribution. It is untrusted input until geometry validation;
zero or multiple candidates require user selection or a Manual fallback.

## DeleteConfirmation

Targets one saved place ID and name. Cancel leaves server and UI unchanged. Confirm
triggers one authenticated delete; remove list/map item only after successful response.
