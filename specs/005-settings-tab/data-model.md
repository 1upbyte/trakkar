# Data Model: Settings Tab and App Reset

## UserProfile

Represents the signed-in user's identity as rendered across Map, People, Places, and
Settings.

| Field | Type | Rules / source |
|---|---|---|
| `userId` | integer or opaque server identifier | Required; taken from authenticated Traccar session. |
| `displayName` | string | Required after trimming; must not be empty. Server-backed through the documented user update operation. |
| `profileImageRef` | server image filename or null | Optional; server-managed image for the signed-in user's Traccar device, referenced by `attributes.deviceImage`. |
| `updateState` | idle, saving, failed | UI state; failed updates preserve the last saved value and expose an error. |

Relationships: one active profile per signed-in app session; a shared profile state
feeds all UI surfaces that display the user's identity. Reset removes the local session
association but does not remove the server image or modify the server-side profile.

## ThemePreference

| Field | Type | Rules / source |
|---|---|---|
| `mode` | `system`, `light`, or `dark` | Required; defaults to `system` for a new install. |
| `isPersisted` | boolean | Persisted locally across normal launches; cleared by confirmed reset. |

State transition: user selection updates the persisted value, then the app shell maps
it to Flutter `ThemeMode`. For `system`, rendering follows the operating system's
current appearance.

## MapAppearancePreference

| Field | Type | Rules / source |
|---|---|---|
| `satelliteThresholdZoom` | valid map zoom level | Shared with feature 002; new installations default to 19 and user selections persist locally. |

Confirmed app reset restores this preference to zoom level 19. The threshold is
separate from the Map tab's initial people-fit camera.

## ServerDetails

Read-only Settings projection of the active connection.

| Field | Type | Rules / source |
|---|---|---|
| `clientUrl` | URI/string or unavailable | Configured tracking client endpoint; show safely normalized address. |
| `managerUrl` | URI/string or unavailable | Configured management/API endpoint; show safely normalized address. |
| `accountName` | string or unavailable | Signed-in account display name when available. |
| `credentials` | secret values | Never part of the view model or rendered projection. |

Incomplete configuration renders an explicit unavailable state. Do not log the view
model if an implementation accidentally includes credential-bearing source objects.

## LocalAppConfiguration

Represents the in-scope locally saved setup required to reconnect and render Settings.

| Field | Type | Reset behavior |
|---|---|---|
| `credentials/session` | secure local values | Clear after confirmed reset. |
| `clientUrl`, `managerUrl` | URI/string | Clear after confirmed reset. |
| `themePreference` | ThemePreference | Clear after confirmed reset; next launch uses system default. |
| `satelliteThresholdZoom` | valid map zoom level | Restore to default 19 after confirmed reset. |
| `profileImageRef` | server image filename | Preserve; image is server-owned data and reset does not mutate the device record. |
| `sdkConnectionConfig` | SDK-owned config | Stop tracker, then clear only connection config via supported bridge; preserve SDK queued positions. |
| `queuedPositions` | SDK-owned persistent records | Preserve; must not be erased or silently redirected to another server/account. |
| `serverAccount/profile/profileImage/places/tracking` | server-owned data | Never mutate or delete during reset. |

## ResetRequest

| Field | Type | Rules |
|---|---|---|
| `status` | idle, confirming, stoppingTracking, clearingLocalConfig, complete, failed, canceled | Progresses only after explicit confirmation; errors remain visible and recoverable. |
| `confirmedAt` | timestamp or null | Set only after the user confirms. |
| `clearedItems` | set of in-scope configuration categories | Audit/UI summary only; must not include secret values. |
| `failureReason` | safe user-facing error or null | Must not contain credentials, tokens, or precise location data. |

State transitions:

```text
idle -> confirming -> canceled
                   -> stoppingTracking -> clearingLocalConfig -> complete
                                                               -> failed
```

The app routes to first-run setup only after all required in-scope clearing succeeds.
If cleanup partially fails, keep the app in a recoverable reset/error state; do not
claim completion or wipe broad storage as a fallback.
