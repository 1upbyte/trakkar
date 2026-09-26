# Traccar API and SDK Contract

## Authenticated user update

Use the configured authenticated Traccar REST client and documented user resource:

- Resource: `User` (`/users/{id}` in the published API reference).
- Read the current authenticated user's identifier and display name from existing
  session state/API behavior.
- Update only the user's `name` field when saving a display name; preserve unrelated
  server fields and follow the existing client's authentication/session mechanism.
- Treat the server response as the committed value. On transport or server failure,
  keep the previous value and show a recoverable error.

## Profile image upload

The profile picture is the server-stored image for the signed-in user's own device:

- Upload image bytes using authenticated `POST /api/devices/{deviceId}/image` with the
  image's content type. The server returns a generated filename.
- Preserve the device's existing fields and attributes, set
  `attributes.deviceImage` to the returned filename, then save with authenticated
  `PUT /api/devices/{deviceId}`.
- Load the image from the server's device media route using the device `uniqueId` and
  stored image filename.
- Do not report success until the upload and device update succeed. On failure, keep
  the previous server image and show a recoverable error.
- Reset App does not remove the server image or change the device record.

Reference: [Traccar API reference](https://www.traccar.org/api-reference) and
[OpenAPI document](https://www.traccar.org/api-reference/openapi.yaml).

## Tracking SDK and reset boundary

- Location reporting remains the responsibility of the official `traccar_client_sdk`
  Flutter package.
- On confirmed reset, call the SDK's stop operation before removing app session and
  endpoint configuration.
- The public Flutter wrapper does not document an operation to clear its persisted
  configuration. If the selected SDK version still lacks one, add a narrowly scoped
  platform bridge or upstream-supported API to clear the connection configuration.
- This operation MUST preserve the SDK's buffered-position SQLite store and other SDK
  data. It MUST NOT clear logs/queue indiscriminately or rebind old queued positions to
  a different account/server.
- If those guarantees cannot be met on both platforms, reset must fail safely and
  remain recoverable; do not substitute a full app-data wipe.

References: [Flutter SDK guide](https://www.traccar.org/traccar-client-sdk-flutter/),
[SDK documentation](https://www.traccar.org/traccar-client-sdk/),
[Flutter wrapper source](https://github.com/traccar/traccar-client-sdk/tree/main/flutter).
