# Feature Specification: QR Login and First-Run Setup

**Feature Branch**: `001-qr-login`

**Created**: 2026-09-24

**Status**: Draft

**Input**: User description: "A QR-code login flow. The QR code should have username, password, client url, and manager url all base64 encoded. Users should be prompted upon new app to either scan QR code or to enter details manually"

## Clarifications

### Session 2026-09-25

- QR payload format: serialize the four values in this exact order as
  `user;password;clienturl;managerurl`, then Base64-encode the complete UTF-8 string
  once. `user` is the login username. The semicolon is a field separator; values
  containing a semicolon are not representable by this format and MUST be rejected by
  QR parsing before sign-in.
- The app identifier for both Android and iOS is `com.1upbyte.trakkar`.

### Session 2026-09-26

- Service URL values need only be non-empty. The app does not locally check their
  schemes, hosts, or embedded credentials; HTTP is allowed without warning, and the app
  does not restrict redirects by origin. The app does not enforce a local login-password
  format or strength policy; the server determines whether credentials are accepted.
- After a QR payload passes local parsing, the app submits it for sign-in immediately;
  QR setup has no destination-review or confirmation prompt. Show the Base64 privacy
  notice on the setup-choice screen before the user starts scanning. Manual setup submits
  only when the user taps its Submit button.
- Manual setup uses the same four values and meanings as QR setup: username, password,
  client URL, and manager URL. Their serialization order applies only to QR payloads.
- After successful authentication, store the username, password, client URL, and manager
  URL in platform secure storage so the app can authenticate again when needed. Do not
  persist raw QR text or credentials from an unverified login attempt.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Set up from a QR code (Priority: P1)

On first launch, a user chooses the QR option and scans a supported code containing
their username, password, client URL, and manager URL. After local parsing succeeds, the
app immediately attempts sign-in.

**Why this priority**: Scanning is the requested quick setup path and avoids retyping
multiple values.

**Independent Test**: With a valid QR code and reachable services, scan it and verify
that the app immediately submits the decoded values and completes sign-in without an
intermediate destination review or confirmation.

**Acceptance Scenarios**:

1. **Given** a fresh app with no saved setup, **When** the user starts onboarding,
   **Then** the app offers QR scanning and manual entry.
2. **Given** a valid QR code with all four required values, **When** the user scans it
   and local parsing succeeds, **Then** the app immediately uses the decoded values to
   attempt sign-in without a destination review or confirmation prompt.
3. **Given** a QR code that is unreadable, incomplete, or invalid, **When** the user scans
   it, **Then** the app explains that setup could not be read and lets the user retry or
   switch to manual entry without submitting credentials.

---

### User Story 2 - Set up by entering details (Priority: P1)

A user chooses manual setup and enters a username, password, client URL, and manager URL
to sign in without a QR code.

**Why this priority**: Manual entry is the required alternative and provides access when
a user cannot scan a code.

**Independent Test**: Enter valid details for reachable services and verify sign-in can
be completed; then submit invalid details and verify the user can correct them.

**Acceptance Scenarios**:

1. **Given** a fresh app, **When** the user chooses manual entry, **Then** the app asks
   for all four required values.
2. **Given** all required values are valid, **When** the user submits them, **Then** the
   app attempts sign-in and reports the outcome.
3. **Given** a required value is missing, **When** the user submits the form, **Then** the
   app identifies the missing value and preserves the other entered values. If a service
   URL cannot be used by the network transport, the app reports that service as
   unavailable and offers the recovery choices in User Story 3.

---

### User Story 3 - Recover from a failed sign-in (Priority: P2)

A user whose credentials are rejected or whose service cannot be reached can understand
the failure, correct the setup, and try again.

**Why this priority**: Sign-in depends on user-provided credentials and service URLs;
clear recovery prevents setup failures from becoming dead ends.

**Independent Test**: Attempt setup with rejected credentials and with an unavailable
service, then verify distinct, actionable feedback and a path to retry or edit details.

**Acceptance Scenarios**:

1. **Given** a service rejects the credentials, **When** sign-in fails, **Then** the app
   reports that the credentials were not accepted and allows correction.
2. **Given** a configured service is unavailable, **When** setup detects the failure,
   **Then** the app shows which service is unavailable, offers an option to view its full
   error details, and presents exactly two actions: Back and Proceed Anyway.
3. **Given** the user chooses Back, **When** the unavailable-service warning is shown,
   **Then** the app returns to setup so the user can review or correct the details.
4. **Given** the user chooses Proceed Anyway, **When** the unavailable-service warning is
   shown, **Then** the app continues to the map without representing the unavailable
   service as reachable or authenticated. A red bar appears at the top saying
   “Connection to server failed” with a Retry button. This bar is also shown whenever any
   server connection fails; Retry retries the failed connection and the bar clears when
   that connection succeeds.

### Edge Cases

- The camera permission is denied or revoked before or during QR scanning.
- The app must show a permission banner if camera access is needed for scanning but not
  granted, or if location access is not both Always and Precise.
- The code is damaged, malformed, contains invalid Base64, or has a missing/empty field.
- A decoded value contains a semicolon, causing the payload to split into more than four
  fields.
- A configured service URL uses a scheme or format the network transport cannot use.
- Credentials are valid for one service but the other configured URL is unavailable.
- The unavailable-service warning may reveal sanitized full error details only after the
  user asks to view them; neither summary nor details may contain credentials, raw QR
  text, or URL user-info.
- Proceeding to the map after unavailable manager authentication does not create an
  authenticated session; the map is shown with the connection-failure bar until Retry
  successfully restores the server connection.
- The user cancels scanning or switches between QR and manual setup.
- The same code is scanned more than once or a sign-in attempt is interrupted.
- A QR code is copied or viewed by someone other than its intended user.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: On first launch before setup is complete, the app MUST offer both QR
  scanning and manual entry. Choosing Proceed Anyway after an unavailable-service
  warning MUST navigate to the map even when manager authentication has not succeeded.
- **FR-002**: The QR login flow MUST accept a standard Base64-encoded UTF-8 string whose
  decoded form is exactly `user;password;clienturl;managerurl` in that order. `user`
  represents the username; the complete delimited string is encoded once.
- **FR-003**: The app MUST decode the complete payload once, split it into exactly four
  non-empty fields, and reject invalid Base64/UTF-8, extra or missing fields, or field
  values containing the separator before attempting sign-in. It MUST NOT validate URL
  values during parsing. Leading and trailing whitespace around the scanned Base64
  payload MUST be trimmed before decoding; whitespace within the payload MUST be
  rejected.
- **FR-004**: After a QR payload passes local parsing, the app MUST immediately submit
  its decoded credentials for sign-in without an intermediate destination review or
  confirmation prompt. Manual-entry credentials MUST be submitted only after the user
  taps Submit. The setup-choice screen MUST show the Base64 privacy notice before QR
  scanning begins.
- **FR-005**: The app MUST let the user enter the same four values manually and submit
  them for sign-in.
- **FR-006**: The app MUST require non-empty username, password, client URL, and manager
  URL values. It MUST NOT locally validate URL schemes, host syntax, URL-embedded
  credentials, or password format/strength. HTTP is allowed without warning or
  confirmation, and the app MUST NOT restrict redirects based on origin. The network
  transport determines whether it can use a configured URL; failures use the recovery
  behavior in FR-007. The server determines whether login credentials are accepted.
- **FR-007**: The app MUST distinguish rejected credentials from unavailable services.
  For an unavailable service, it MUST identify the affected service, show a safe warning,
  offer user-requested sanitized full error details, and present exactly two actions:
  Back and Proceed Anyway. Back returns to setup for review or correction. Proceed Anyway
  navigates to the map without claiming that the unavailable service is reachable or
  authenticated. A red bar at the top MUST say “Connection to server failed” and include
  a Retry button whenever a server connection fails. Retry MUST retry the failed
  connection, including the failed manager authentication attempt when applicable, and
  the bar MUST clear when the connection succeeds. A session MUST be established only
  after manager authentication succeeds.
- **FR-008**: The app MUST allow a user to leave QR scanning and choose manual entry.
- **FR-009**: The app MUST treat QR payloads and decoded credentials as secrets: it MUST
  NOT include them in logs, diagnostics, or user-visible error details. It MUST also
  redact URL user-info from logs, diagnostics, and errors.
- **FR-010**: The app MUST explain that Base64 is encoding rather than encryption and
  that a QR code containing these values must be kept private.
- **FR-011**: The app MUST scan QR codes supplied by an existing external workflow. Creating
  or displaying QR codes is outside this feature's scope.
- **FR-012**: Android and iOS app builds MUST use the shared app identifier
  `com.1upbyte.trakkar`.
- **FR-013**: After successful manager authentication, the app MUST persist the username,
  password, client URL, and manager URL in platform secure storage to support future
  authentication. Credentials from an unsuccessful or unverified attempt MUST NOT be
  persisted. The raw QR payload MUST NOT be persisted.
- **FR-014**: If camera permission is denied or revoked while QR scanning is selected,
  the app MUST show the shared red top bar saying camera permission is needed, with a
  permission request action labeled Re-ask. The app MUST also show this bar whenever
  location permission is not both Always and Precise, saying those permissions are
  needed and offering Re-ask. The location bar MUST clear once both requirements are
  granted. Scan cancellation MUST offer Scan Again or Enter Details.

### Key Entities *(include if feature involves data)*

- **Login Details**: Username and password paired with the client and manager service
  URLs; supplied by scanning a code or entering values manually.
- **QR Login Code**: A scannable standard Base64 representation of the complete UTF-8
  string `user;password;clienturl;managerurl`.
- **Setup Attempt**: A user's attempt to validate login details and reach the signed-in
  app state, including success or an actionable failure.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: In usability validation, at least 90% of users with valid setup details
  complete either onboarding path without assistance in two minutes or less.
- **SC-002**: 100% of valid QR test cases provide the same four values as the source
  details, including payloads with surrounding whitespace; 100% of invalid or incomplete
  QR cases, including payloads with internal whitespace, are rejected before sign-in.
- **SC-003**: In all tested rejected-credential and unavailable-service cases, users
  receive distinct feedback. An unavailable-service warning identifies the service,
  reveals sanitized full error details only on request, and offers Back and Proceed
  Anyway; Back returns to setup, and Proceed Anyway opens the map without claiming the
  unavailable service is authenticated. On server connection failure, the map displays
  the red connection-failure bar with Retry; successful reconnection clears the bar.
- **SC-004**: No tested QR payload, username, or password appears in application logs,
  diagnostics, or error messages.
- **SC-005**: Android and iOS build metadata report the same app identifier,
  `com.1upbyte.trakkar`.

## Assumptions

- First launch means the app has no completed login setup saved for the current user.
- The same username and password apply to both configured service URLs.
- The four values are joined in the specified order with semicolons, then the entire
  UTF-8 string is Base64-encoded once. Semicolons cannot appear in field values.
  Base64 does not provide confidentiality; the QR code is treated as a
  credential-bearing secret.
- Manual entry and QR scanning lead to the same sign-in behavior and signed-in app
  experience.
- QR codes are created and supplied through an existing external workflow; this feature
  covers scanning them, not creating or displaying them.
- Existing authentication and session behavior is reused after setup succeeds.
