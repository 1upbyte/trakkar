# Data Model: People Tab

## Person

| Field | Type | Rules |
|---|---|---|
| `personId` | stable ID | Stable key for row, map selection and updates. |
| `deviceId` | Traccar ID or null | Source mapping when the person is represented by a tracked device. |
| `name` | string | Current shared profile/device display name. |
| `profileImageRef` | image reference or null | If null/unavailable, render initials. |
| `location` | PersonLocation or null | Latest available server report; missing does not remove person. |

## PersonLocation

| Field | Type | Rules |
|---|---|---|
| `latitude`, `longitude` | finite numbers | Valid coordinates only. |
| `reportedAt` | timestamp or unknown | Required to assess freshness when available. |
| `freshness` | current, stale, unknown | Stale state is explicit and never labeled current. |
| `description` | string | Saved-place name, server address, then coordinates. |

## PeopleListState

Contains loading/ready/empty/error status, people ordered alphabetically (per spec
assumption), and retained scroll offset. Updates from the shared data feed refresh rows
without replacing the list state.

## PersonSelection

Request carries `personId` and entry source. A known location routes to Map using the
shared map selection action and stores a camera snapshot; an unknown location returns
an unavailable-location message without presenting a map position.
