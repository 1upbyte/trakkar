# Setup UI Contract

- Before first successful setup, present Scan QR and Enter Details choices.
- Request camera access only after Scan QR is selected. Denial or scan cancellation offers
  retry and manual entry.
- If camera access is denied or revoked while QR scanning is selected, show the shared
  red top bar asking for camera permission with a Re-ask button. Keep Enter Details
  available. Canceling a scan offers Scan Again or Enter Details.
- Show a non-blocking notice on the setup-choice screen explaining that Base64 is not
  encryption and QR codes containing credentials must be kept private.
- Parse a scan locally. Invalid input displays a safe explanation and does not submit
  credentials. After successful parsing, immediately submit the decoded values for
  sign-in without showing a destination-review or confirmation prompt.
- Manual-entry values are submitted only when the user taps Submit. Keep the password
  masked in the form.
- Empty required form fields stay editable. Do not locally reject URL schemes, hosts,
  embedded URL credentials, HTTP, redirects, or password formats. Errors distinguish
  rejected credentials from unavailable services without echoing secrets.
- When a service is unavailable, show a warning naming that service. Offer a control to
  reveal sanitized full error details on request and exactly two actions: Back and
  Proceed Anyway. Back returns to setup so the user can review or correct details.
  Proceed Anyway navigates to the map without representing the unavailable service as
  reachable or authenticated.
- Whenever a server connection fails, show a red bar at the top reading “Connection to
  server failed” with a Retry button. Retry attempts the failed connection again; clear
  the bar when that connection succeeds. This also applies after the user proceeds to the
  map without an authenticated manager session. If manager authentication succeeds on
  retry, establish the session then; do not treat the earlier Proceed Anyway choice as
  authentication.
- Show the shared red top bar with a Re-ask button whenever location permission is not
  both Always and Precise. Remove the location-permission bar after the platform reports
  both permission conditions granted.
- Full error details may include safe diagnostic context, but MUST omit credentials, raw
  QR text, URL user-info, and any other secret. Never display parser/scanner exception
  text verbatim.
