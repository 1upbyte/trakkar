# Trakkar

This repository contains the Trakkar product specifications and implementation plan.

## QR login payload format

The QR code is supplied by an external workflow. Its decoded UTF-8 text must contain
exactly four non-empty values in this order, separated by exactly three semicolons:

```text
username;password;client-url;manager-url
```

Base64-encode the complete UTF-8 string once, using the standard RFC 4648 alphabet and
canonical padding. Do not encode the fields separately. No value may contain a
semicolon. The app trims whitespace from the beginning and end of the scanned Base64
text and rejects whitespace inside it. It rejects any decoded payload that does not
have exactly four non-empty fields.

Base64 is encoding, not encryption. The QR code contains login credentials; keep it
private. After valid local parsing, the app submits the credentials immediately without
a confirmation prompt. The manager URL is used for authentication and session setup; the
client URL configures the tracking SDK.

## Friend map live tracking

Optional 30-second tracking sessions use a Docker sidecar, Android FCM data messages,
and an iOS location push extension. See [setup, architecture, limitations, and tests](docs/live-tracking.md).
