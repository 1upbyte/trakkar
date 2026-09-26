# Data Model: QR Login and First-Run Setup

## LoginDetailsDraft

| Field | Type | Rules |
|---|---|---|
| `username` | string | Required, trimmed according to existing auth rules. |
| `password` | secret string | Required and masked in UI; no local password-format or strength validation; server determines acceptance. Keep transient until authentication succeeds, then store only in platform secure storage. Never serialize to logs. |
| `clientUrl` | string | Required non-empty value; preserve as entered/decoded without local scheme, host, or embedded-credential validation. |
| `managerUrl` | string | Required non-empty value; preserve as entered/decoded without local scheme, host, or embedded-credential validation. |
| `source` | qr or manual | Used for flow behavior/analytics category only; never log payload. |

## StoredLoginDetails

Persist the username, password, client URL, and manager URL in platform secure storage
only after manager authentication succeeds. Reuse these values when authentication is
needed again. Never persist the raw QR payload or an unsuccessful/unverified draft.

## QRLoginPayload

Raw scanned text is one standard Base64 string. Trim leading and trailing whitespace,
reject whitespace remaining inside the payload, then decode once as UTF-8 and parse the
exact four-field grammar `user;password;clienturl;managerurl`. The field count must be
exactly four and every field must be non-empty; any additional semicolon is invalid.
Raw payload and decoded credentials are sensitive. Discard the raw payload after local
parsing; keep decoded credentials transient until success or the setup attempt is
abandoned. On success, copy login details to platform secure storage and clear transient
credential references. Invalid Base64, invalid UTF-8, or malformed field count is
rejected before authentication.

## SetupAttempt

| Field | Type | Rules |
|---|---|---|
| `state` | choosing, scanning, editing, authenticating, success, rejected, unavailable, proceeding, canceled | A valid QR payload moves directly from scanning to authenticating. Error categories distinguish bad credentials from service/network failure. `proceeding` navigates to the map after the user chooses Proceed Anyway; it does not assert that an unavailable service is authenticated. |
| `details` | LoginDetailsDraft or null | Transient credentials stay in memory for correction/retry, are never persisted before successful authentication, and are cleared after successful secure-storage persistence or when the user abandons setup. |
| `safeError` | enum/message or null | Identifies the affected service and contains no password, payload, or URL user-info. Full sanitized details are exposed only when requested by the user. |
| `sessionRef` | secure session handle or null | Created only after successful auth and stored using the existing session policy; remains null when the user proceeds without manager authentication. |

State flow:

```text
first-run -> choosing -> scanning -> authenticating -> success
                    \-> manual form -> submit --------/ -> rejected -> edit/retry
                                                                   -> unavailable -> warning
                                                                                  -> Back -> edit/review
                                                                                  -> Proceed Anyway -> map + connection-failure bar
```

Camera denial or cancellation returns to choosing/manual entry. QR parsing itself is
local; successful parsing immediately triggers authentication. A server connection
failure shows the shared top red bar with Retry; it clears after the failed connection
succeeds.
