# trakkar

Trakkar is a Flutter client for Android and iOS that:

- sends this phone's background location using only the official
  [`traccar_client_sdk`](https://pub.dev/packages/traccar_client_sdk);
- signs into an unmodified Traccar server using its REST API;
- receives devices and positions in real time from `/api/socket`;
- displays all devices available to the provisioned manager account on a
  Google Maps or OpenStreetMap-based map;
- displays official Traccar device images as profile-picture map markers; and
- shares friendly place names as tagged geofences on the unmodified server;
- shares map SDK keys through the manager account so no key is compiled in; and
- keeps everyone's position fresh while any phone has the map open.

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
device position at a neighborhood zoom. Tap a picture to open a bottom sheet
with the person's name and current address. A user can change their own
picture from Settings; the image uses Traccar's official device-image endpoint.

### Map styles

Settings offers three map stacks:

- **Google Maps** (Standard, Satellite, Hybrid, Terrain) through the official
  Maps SDK for Android and Maps SDK for iOS. Google does not charge for mobile
  native map loads and sets no usage cap on them, but the SDK still needs an
  API key from a Google Cloud project with the two mobile Maps SDKs enabled.
  Profile bubbles are rendered to bitmaps for the native marker layer. In the
  dark theme the Standard style uses a night palette.
- **OpenFreeMap** vector styles (Positron, Bright, Liberty, Dark, Fiord). No
  key. Positron keeps road and city context but omits restaurant, shop, and
  other POI labels.
- **MapTiler satellite** raster imagery, which needs a MapTiler key.

**Satellite when zoomed in** mimics Life360: the map stays a street map while
zoomed out and switches to imagery once the camera is closer than roughly
zoom 15.5, switching back below zoom 14.5 so pinching near the threshold does
not flicker. With Google Maps this swaps the Standard or Terrain style for
Hybrid tiles. With OpenFreeMap styles it overlays MapTiler imagery when a
MapTiler key exists. The toggle is available whenever the chosen style is not
already imagery-only, including all Google Maps styles.

### Map keys live on the server

Trakkar never compiles a map key into the app. Both keys are stored as
attributes on the Traccar **manager user** (`trakkarGoogleMapsApiKey` and
`trakkarMapTilerApiKey`) using the standard `PUT /api/users/{id}` endpoint,
which any non-readonly user may call for its own record. Every phone signed
into the same account receives the keys from the `POST /api/session` response
and caches them in Android Keystore / iOS Keychain so the map can start
offline. Saving keys in Settings on one phone updates every other phone at its
next sign-in.

The key reaches the native SDK at runtime:

- iOS calls `GMSServices.provideAPIKey` through a method channel before the
  first map view is created.
- Android has no public runtime setter. Trakkar writes the key into the
  process's cached `ApplicationInfo.metaData`, which the Maps SDK reads when
  the first map is created. Android 11 and later cache that record per process
  so the runtime key is honored. Android 7 through 10 hand out fresh copies,
  so those devices need the optional build-time fallback: set
  `GOOGLE_MAPS_API_KEY=...` in `android/local.properties`, as a Gradle project
  property, or in the environment before building.

Restrict the Google key to the Android package name plus signing SHA-1 and to
the iOS bundle ID in the Google Cloud console. That restriction, not secrecy,
is what protects the key; treat the manager account as the trust boundary.

### Live sharing while the map is open

When any phone shows the Map tab in the foreground, everyone else's phone
sends a fresh position so the map updates like a live view. Traccar's REST API
does not push device edits over `/api/socket`, so the mechanism is:

1. The watching phone writes `attributes.trakkarWatchUntil` (epoch
   milliseconds, 75 seconds ahead) onto its **own** device every 30 seconds
   through `PUT /api/devices/{id}`, and clears it when the map is hidden. It
   also asks the Traccar Client SDK for an immediate position of its own.
2. Every phone with tracking enabled polls `GET /api/devices` every 45 seconds
   while idle. When another device's `trakkarWatchUntil` is in the future, the
   phone calls the SDK's `requestPosition()` (at most once every 12 seconds)
   and polls every 15 seconds until the watch expires. Manual refreshes and
   socket device updates are evaluated the same way.

Location collection still happens only inside the official Traccar Client
SDK. On Android the SDK's foreground service keeps the app process alive, so
background phones respond. iOS suspends the app between location updates, so a
backgrounded iPhone responds on its next wake-up rather than immediately.
Settings shows a "Live sharing active" card naming the people currently
watching.

The people-count pill on the map and the People navigation tab open a live list
of every device shared with the manager account. Each row displays a matching
friendly place first; reverse geocoding runs only when no named place covers the
position. Devices that have not reported a position remain visible in the list.

The app theme defaults to the phone's system appearance. Settings can override
it with Light or Dark, and the preference is stored on the device.

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

Reverse geocoding is server-side only. When a position has no friendly place
and Traccar did not attach an address, the app calls `GET /api/server/geocode`
on the manager server. Configure the geocoder (Nominatim, Geoapify, MapTiler,
and so on) in the Traccar server settings; the phone holds no geocoding keys.

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
