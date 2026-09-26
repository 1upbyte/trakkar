# Setup UI Contract

- Before first successful setup, present Scan QR and Enter Details choices.
- Request camera access only after Scan QR is selected. Denial or scan cancellation offers
  retry and manual entry.
- Parse and validate a scan before showing a destination review. Invalid input displays
  a safe explanation and does not submit credentials.
- The review shows the configured client/manager destinations (redacting embedded URL
  user-info) and explains that Base64 is not encryption and the QR must be kept private.
  The login password and raw QR text are not shown.
- Continue requires explicit confirmation. Manual and QR details use the same submit
  action and authentication behavior.
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
- Full error details may include safe diagnostic context, but MUST omit credentials, raw
  QR text, URL user-info, and any other secret. Never display parser/scanner exception
  text verbatim.
