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
- When credentials are rejected, show a safe message that they were not accepted and
  exactly three actions: Back, Retry, and Proceed Anyway. When a service is unavailable,
  name that service, offer sanitized full error details on request, and show the same
  three actions. Retry resubmits the current credentials. Back returns to editable setup
  with all entered details retained. Connection loss during authentication uses the
  unavailable-service warning. Proceed Anyway navigates to the map without claiming
  authentication or creating a session.
- While authentication is in progress, stop accepting QR detections and disable actions
  that could start another authentication request. Ignore duplicate scan detections.
- Whenever a server connection fails, show a red bar at the top reading “Connection to
  server failed” with a Retry button. Retry repeats the failed operation; if the failed
  operation was authentication, resubmit the retained transient login details. Clear the
  bar when the connection succeeds. This also applies after the user proceeds to the map
  without an authenticated manager session. If manager authentication succeeds on retry,
  persist the login details and establish the session then; do not treat the earlier
  Proceed Anyway choice as authentication.
- Show the shared red top bar with a Re-ask button whenever location permission is not
  both Always and Precise. Remove the location-permission bar after the platform reports
  both permission conditions granted.
- Full error details may include safe diagnostic context, but MUST omit credentials, raw
  QR text, URL user-info, and any other secret. Never display parser/scanner exception
  text verbatim.
