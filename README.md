# trakkar

Trakkar is a Flutter client for Android and iOS that:

- sends this phone's background location using only the official
  [`traccar_client_sdk`](https://pub.dev/packages/traccar_client_sdk);
- signs into an unmodified Traccar server using its REST API;
- receives devices and positions in real time from `/api/socket`;
- displays all devices available to the provisioned manager account on an
  OpenStreetMap map;
- displays official Traccar device images as profile-picture map markers; and
- shares friendly place names as tagged geofences on the unmodified server.

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

The app loads initial state from `GET /api/devices`, `GET /api/positions`, and
`GET /api/geofences`, then consumes live `devices` and `positions` updates from
`/api/socket`.

People appear as screen-upright profile-picture circles without permanent name
labels, even when the map is rotated. The default view centers on this phone's
device position at a neighborhood zoom. The OpenFreeMap Positron vector style
keeps useful road and city context but omits restaurant, shop, and other POI
labels. Tap a picture to open a bottom sheet with the person's name and current
address. A user can change their own picture from Settings; the image uses
Traccar's official device-image endpoint.

While Traccar reports a person in motion, their map bubble shows walking below
10 mph or driving above 10 mph, together with the latest speed in mph. Motion
uses the standard Traccar position attribute when available and also requires
at least 1 mph, preventing a delayed server motion state from leaving a badge
visible at 0 mph. The official Traccar
Client SDK is configured for 25-meter / 30-second movement updates and retains
its stop detection to pause frequent GPS work while stationary.

Use the bottom sheet or long-press the map to create a named place and choose
its radius. These names are tagged circular Traccar geofences, so every app
signed into the same manager account sees them after refresh. A local cache is
used only for offline display. Friendly names take priority over
reverse-geocoded addresses.

The exact unmodified-server protocol, migration behavior, security rules, and
an optional first-class server design are documented in
[`SERVER-MODS.md`](SERVER-MODS.md).

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
camera, photo-library, and background-location usage. `AppDelegate`
reconstructs the persisted SDK tracker early when iOS relaunches the app for a
background location event. On first tracking start, the SDK requests iOS Always
location authorization. If the user previously granted only While Using,
Trakkar requests the iOS-supported upgrade to Always; location collection itself
continues to be performed exclusively by the Traccar SDK.

While signed in, Trakkar checks the settings required for reliable background
tracking whenever the app opens or returns from system settings. A red banner
links to location settings when iOS is not set to Always or Android is not set
to Allow all the time. On Android 6 and newer it also links to the system battery
optimization list until Trakkar is exempt. iOS has no equivalent per-app battery
optimization exemption, so no non-actionable battery warning is shown there.

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
