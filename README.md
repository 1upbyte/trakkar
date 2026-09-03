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

The app loads initial state from `GET /api/devices`, `GET /api/positions`,
`GET /api/geofences`, and `GET /api/server`, then consumes live `devices` and
`positions` updates from `/api/socket` while the app is visible. The manager
socket closes in the background and reconnects on resume; repeated failures use
an exponential backoff capped at five minutes. While the map tab is visible and
the app is in the foreground, this phone asks the tracking SDK for a fresh
position every 30 seconds and polls all server positions every 15 seconds.
Polling stops when the map is hidden or the app leaves the foreground. Normal
background tracking uses a 120-second/75-metre request with stop detection.

People appear as screen-upright profile-picture circles without permanent name
labels, even when the map is rotated. The default view centers on this phone's
device position at a neighborhood zoom. The OpenFreeMap Positron vector style
keeps useful road and city context but omits restaurant, shop, and other POI
labels. At zoom 20 and above, the default-on satellite setting overlays
MapTiler `satellite-v4` 512-pixel HiDPI tiles. Satellite tiles are cached for 90
days with a 512 MB cache limit, and map interaction is limited to zoom levels 2
through 21. The MapTiler key comes from the Traccar server attribute
`trakkarMapTilerKey` and is held only in memory by the client. Nearby people are
clustered into overlapping profile previews; tapping a cluster spreads its
members apart, and tapping a person centers and zooms the map before opening a
low, draggable details sheet that does not block the map. A user can change
their own picture from Settings; the app applies an on-device square crop before
using Traccar's official device-image endpoint.

The people-count pill on the map and the People navigation tab open a live list
of every device shared with the manager account. Each row displays a matching
friendly place first; reverse geocoding runs only when no named place covers the
position. Devices that have not reported a position remain visible in the list.

The app theme defaults to the phone's system appearance. Settings can override
it with Light or Dark, and the preference is stored on the device.

While Traccar reports a person in motion, their map bubble shows walking below
10 mph or driving at 10 mph and above, together with the latest speed in mph.
After driving begins, the car indicator remains until a full minute of newly
reported sub-10 mph speed has elapsed, preventing short stops and GPS jitter
from flipping the icon. Motion uses the standard Traccar position attribute
when available and also requires at least 1 mph. The official Traccar
Client SDK is configured for 75-metre / 120-second movement updates and retains
its stop detection to pause frequent GPS work while stationary.

Use the bottom sheet or long-press the map to create a named place and choose
its radius. These names are tagged circular Traccar geofences, so every app
signed into the same manager account sees them after refresh. A local cache is
used only for offline display. Friendly names take priority over
reverse-geocoded addresses.

The exact unmodified-server protocol, migration behavior, security rules, and
an optional first-class server design are documented in
[`SERVER-MODS.md`](SERVER-MODS.md).

Reverse geocoding is configured entirely on the Traccar server. The client has
no provider or API-key controls and only calls Traccar's authenticated
`GET /api/server/geocode` endpoint. See `SERVER-MODS.md` for server-side key
configuration.

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
links to permission settings when iOS is not set to Always, Android is not set
to Allow all the time, or Android's Physical activity permission is missing.
On Android 6 and newer it also links to the system battery optimization list
until Trakkar is exempt. iOS has no equivalent per-app battery optimization
exemption, so no non-actionable battery warning is shown there.

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
