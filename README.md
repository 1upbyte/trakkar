# trakkar

Trakkar is a Flutter client for Android and iOS that:

- sends this phone's background location using only the official
  [`traccar_client_sdk`](https://pub.dev/packages/traccar_client_sdk);
- signs into an unmodified Traccar server using its REST API;
- receives devices and positions in real time from `/api/socket`;
- displays all devices available to the provisioned manager account on an
  OpenStreetMap map;
- keeps user-defined place names locally until the server supports them.

The application ID and iOS bundle ID are both `com.oneupbyte.trakkar`.

## Provisioning QR format

The server generates the QR code. Trakkar only reads it.

Before base64 encoding, the UTF-8 payload is:

```text
clientUrl;managerUrl;managerUsername;managerPassword
```

Semicolons after the third separator are treated as part of the password. Both
standard and URL-safe base64, with or without padding, are accepted.

Base64 is an encoding, not encryption. The QR code grants access to the manager
account and must be handled like a password. Use HTTPS endpoints in production.
HTTP is enabled for compatibility with self-hosted Traccar instances and local
development.

## Onboarding behavior

1. Scan the server-generated provisioning code, or manually enter the client
   URL, manager URL, manager username, and manager password.
2. Trakkar creates a normal Traccar session using the embedded manager
   credentials.
3. Enter a first name and username.
4. The username becomes the Traccar device `uniqueId` reported by the official
   tracking SDK.
5. If that `uniqueId` exists, Trakkar asks for confirmation before reusing it
   and updating its display name. Otherwise, it creates the device through
   `POST /api/devices`.

Provisioning credentials are stored using Android Keystore/iOS Keychain through
`flutter_secure_storage`. The WebSocket uses only the in-memory `JSESSIONID`
cookie returned by Traccar.

## Map and place names

The app loads initial state from `GET /api/devices` and `GET /api/positions`,
then consumes live `devices` and `positions` updates from `/api/socket`.

Long-press the map to create a named place and choose its radius. These names
are stored on the phone and take priority over reverse-geocoded addresses.
Reverse geocoding can use:

- the configured Traccar server;
- Geoapify with an API key;
- MapTiler with an API key;
- a custom URL template containing `{lat}`, `{lon}`, and optionally `{key}`.

API keys are kept in secure device storage.

## Platform requirements

- Flutter 3.47 or newer
- Android API 24 or newer
- iOS 15 or newer
- Full Xcode installation for iOS builds

The official Traccar SDK supplies Android's tracking permissions and foreground
service declarations. The iOS project declares always-on location, motion,
camera, and background-location usage. `AppDelegate` reconstructs the persisted
SDK tracker early when iOS relaunches the app for a background location event.

## Build and verify

```sh
flutter pub get
flutter analyze
flutter test
flutter build apk --debug
flutter build ios --simulator --debug
```

The iOS build command requires a complete Xcode installation. Signing settings
and final store assets must be configured before release builds.
