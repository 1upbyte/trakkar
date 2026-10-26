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
v2;clientUrl;managerUrl;liveTrackingUrl;managerUsername;managerPassword
```

The live-tracking URL is optional; leave its field empty to disable live tracking.
It must use HTTPS. Semicolons after the fifth separator are part of the password.
Legacy four-field codes (`clientUrl;managerUrl;managerUsername;managerPassword`)
remain supported and disable live tracking. Both
standard and URL-safe base64, with or without padding, are accepted.

Base64 is an encoding, not encryption. The QR code grants access to the manager
account and must be handled like a password. Use HTTPS endpoints in production.
HTTP is enabled for compatibility with self-hosted Traccar instances and local
development.

## Setup links for friends

On a configured phone, open **Settings → Copy setup link**, then paste the link
into a private message. The friend must already have Trakkar installed.
If the messaging app does not make the link tappable, paste it into the
**Setup link** field on Trakkar's login page and tap **Use setup link**.
Beside **Copy setup link**, **Share QR code** displays a scannable code and
offers **Share image** to send it through the system share sheet. The other
phone can scan it with **Scan server code**; legacy server QR codes still work.

The format is:

```text
trakkar://setup?data=<URL-encoded base64 provisioning payload>
```

The `data` parameter uses the same legacy or v2 payload as provisioning QR codes.
For example, a server can generate a link using Python:

```python
import base64
from urllib.parse import urlencode

payload = (
    "v2;https://client.example.com;https://manager.example.com;"
    "https://live.example.com;manager@example.com;password"
)
data = base64.urlsafe_b64encode(payload.encode("utf-8")).decode("ascii")
link = "trakkar://setup?" + urlencode({"data": data})
```

Android and iOS open the setup screen when Trakkar is closed or already running.
The recipient reviews the server and account, continues to the prefilled login
form, taps **Connect**, and chooses their own first name and device username.
Opening a link does not log in or start tracking automatically. If the phone is
already configured, replacing its setup requires an explicit confirmation first.
Canceling before replacement preserves the existing setup.

Like QR codes, these links include the manager password and grant access to that
account. Base64 does not encrypt them. Share only with trusted recipients; create
a separate Traccar account and provisioning payload when a friend should have
different access. Custom-scheme links require the app to be installed and do not
provide an App Store fallback.

## Onboarding behavior

1. Scan the server-generated provisioning code, or manually enter the client
   URL, manager URL, optional live-tracking URL, manager username, and manager password.
2. Trakkar creates a normal Traccar session using the embedded manager
   credentials.
3. Enter a first name and username.
4. The username becomes the Traccar device `uniqueId` reported by the official
   tracking SDK.
5. If that `uniqueId` exists, Trakkar warns before using its profile on this phone
   and updating its display name. Its history, picture, and sharing are preserved.
   Otherwise, it creates the device through `POST /api/devices`.
6. When live tracking is configured, the sidecar records this phone automatically.
   Confirming a duplicate username revokes the old phone's live-tracking connection;
   no device-owner JSON mapping is needed. Stop tracking on the old phone to prevent
   ordinary location uploads from both phones under the same username.

Provisioning credentials are stored using Android Keystore/iOS Keychain through
`flutter_secure_storage`. The WebSocket uses only the in-memory `JSESSIONID`
cookie returned by Traccar.

## Map and place names

The app loads initial state from `GET /api/devices`, `GET /api/positions`,
`GET /api/geofences`, and `GET /api/server`, then consumes live `devices` and
`positions` updates from `/api/socket` while the app is visible. The manager
socket closes in the background and reconnects on resume; repeated failures use
an exponential backoff capped at five minutes.

When live tracking is configured, opening the Map tab in the foreground requests
live tracking for the account's devices, including this phone if it is in that
list. Participating phones temporarily request location updates every five
seconds, even if their own maps are closed. Viewer sessions renew every 15 seconds;
this renews the live tracking request rather than polling positions. Map positions
arrive through `/api/socket`. There is no separate 30-second location timer or
15-second position polling loop. Leaving the Map tab or backgrounding the app
releases that viewer's session. Once all viewers leave or their sessions expire,
phones restore normal tracking. Without a live-tracking URL, opening the map
does not change the tracking profile.

Normal background tracking requests time-based 10-minute updates with no distance filter.
The SDK overrides the interval with zero when a positive distance filter is set.
Android uses that interval for native location requests; iOS controls its own
location delivery cadence. After two stationary minutes the SDK pauses frequent
GPS work and monitors a 100-metre stationary region so leaving it wakes tracking
again.

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
Client SDK retains stop detection in the normal background profile to pause
frequent GPS work while stationary; the temporary live tracking profile disables
stop detection.

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

The iOS build command requires a complete Xcode installation. iOS release
signing and final store assets must be configured before store submission.

To build and publish an Android APK manually, open **Actions → Android release
→ Run workflow** and enter the GitHub release name and description. The workflow
attaches `app-release.apk` to a GitHub release with a unique tag.

The manual release workflow signs with a stable release keystore and requires
these GitHub Actions repository secrets: `ANDROID_KEYSTORE_BASE64`,
`ANDROID_KEYSTORE_PASSWORD`, `ANDROID_KEY_ALIAS`, and `ANDROID_KEY_PASSWORD`.
This checkout has an ignored keystore at `android/trakkar-upload-key.jks` and
local credentials in `android/key.properties`. Create the base64 secret on macOS
with `base64 -i android/trakkar-upload-key.jks | tr -d '\n'`; use the matching
values from `android/key.properties` for the other secrets. Local release builds
use that keystore when the properties file exists and fall back to the debug key
otherwise. Keep the keystore and passwords backed up securely; the workflow does
not commit them.

## Friend map live tracking

Optional live tracking uses a Docker sidecar and native FCM/APNs handlers. See
[the deployment and notification flow guide](docs/live-tracking.md).
