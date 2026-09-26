# Data Model: QR Login and First-Run Setup

## LoginDetailsDraft

| Field | Type | Rules |
|---|---|---|
| `username` | string | Required, trimmed according to existing auth rules. |
| `password` | secret string | Required; masked in UI, memory-only until successful auth, never serialized to logs. |
| `clientUrl` | absolute HTTP(S) URI | Required; valid host; reject embedded credentials. |
| `managerUrl` | absolute HTTP(S) URI | Required; valid host; reject embedded credentials. |
| `source` | qr or manual | Used for flow behavior/analytics category only; never log payload. |

## QRLoginPayload

Raw scanned text is one standard Base64 string. Decode it once as UTF-8, then parse the
exact four-field grammar `user;password;clienturl;managerurl`. The field count must be
exactly four and every field must be non-empty; any additional semicolon is invalid.
Raw payload and decoded credentials are sensitive and short-lived. Invalid Base64,
invalid UTF-8, or malformed field count is rejected before authentication.

## SetupAttempt

| Field | Type | Rules |
|---|---|---|
| `state` | choosing, scanning, previewing, editing, authenticating, success, rejected, unavailable, canceled | Error categories distinguish bad credentials from service/network failure. |
| `details` | LoginDetailsDraft or null | Cleared on cancel/failure completion as appropriate. |
| `safeError` | enum/message or null | Contains no password, payload, or URL user-info. |
| `sessionRef` | secure session handle or null | Created only after successful auth and stored using the existing session policy. |

State flow:

```text
first-run -> choosing -> scanning -> previewing -> authenticating -> success
                    \-> manual form --------------------/       -> rejected/unavailable -> edit/retry
```

Camera denial or cancellation returns to choosing/manual entry. No network request is
made from scan parsing or the destination-preview screen.
