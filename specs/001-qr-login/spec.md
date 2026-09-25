# Feature Specification: QR Login and First-Run Setup

**Feature Branch**: `001-qr-login`

**Created**: 2026-09-24

**Status**: Draft

**Input**: User description: "A QR-code login flow. The QR code should have username, password, client url, and manager url all base64 encoded. Users should be prompted upon new app to either scan QR code or to enter details manually"

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Set up from a QR code (Priority: P1)

On first launch, a user chooses the QR option, scans a supported code containing their
username, password, client URL, and manager URL, reviews the service destinations, and
continues to sign in.

**Why this priority**: Scanning is the requested quick setup path and avoids retyping
multiple values.

**Independent Test**: With a valid QR code and reachable services, scan the code and
verify the user can review its destinations and complete sign-in.

**Acceptance Scenarios**:

1. **Given** a fresh app with no saved setup, **When** the user starts onboarding,
   **Then** the app offers QR scanning and manual entry.
2. **Given** a valid QR code with all four required values, **When** the user scans and
   confirms the displayed destinations, **Then** the app uses the decoded values to
   attempt sign-in.
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
3. **Given** a required value is missing or a URL cannot be used, **When** the user
   submits the form, **Then** the app identifies what needs correction and preserves the
   other entered values.

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
2. **Given** a service cannot be reached, **When** sign-in fails, **Then** the app reports
   a connection problem separately from rejected credentials and allows retry.

### Edge Cases

- The camera permission is denied or revoked before or during QR scanning.
- The code is damaged, malformed, contains invalid Base64, or has a missing/empty field.
- A decoded URL uses an unsupported scheme or is malformed.
- Credentials are valid for one service but the other configured URL is unavailable.
- The user cancels scanning or switches between QR and manual setup.
- The same code is scanned more than once or a sign-in attempt is interrupted.
- A QR code is copied or viewed by someone other than its intended user.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: On first launch before setup is complete, the app MUST offer both QR
  scanning and manual entry.
- **FR-002**: The QR login flow MUST accept a code containing a username, password,
  client URL, and manager URL, with each value Base64-encoded separately.
- **FR-003**: The app MUST decode the four values and reject codes with missing, empty,
  malformed, or undecodable values before attempting sign-in.
- **FR-004**: Before sending decoded credentials, the app MUST show the service
  destinations and require the user to confirm continuing.
- **FR-005**: The app MUST let the user enter the same four values manually and submit
  them for sign-in.
- **FR-006**: The app MUST validate that required values are present and that both URLs
  are well-formed before attempting sign-in.
- **FR-007**: The app MUST distinguish rejected credentials from unavailable services
  and provide a way to correct values or retry.
- **FR-008**: The app MUST allow a user to leave QR scanning and choose manual entry.
- **FR-009**: The app MUST treat QR payloads and decoded credentials as secrets: it MUST
  NOT include them in logs, diagnostics, or user-visible error details.
- **FR-010**: The app MUST explain that Base64 is encoding rather than encryption and
  that a QR code containing these values must be kept private.
- **FR-011**: The app MUST scan QR codes supplied by an existing external workflow. Creating
  or displaying QR codes is outside this feature's scope.

### Key Entities *(include if feature involves data)*

- **Login Details**: Username and password paired with the client and manager service
  URLs; supplied by scanning a code or entering values manually.
- **QR Login Code**: A scannable representation of the four separately Base64-encoded
  login detail values.
- **Setup Attempt**: A user's attempt to validate login details and reach the signed-in
  app state, including success or an actionable failure.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: In usability validation, at least 90% of users with valid setup details
  complete either onboarding path without assistance in two minutes or less.
- **SC-002**: 100% of valid QR test cases provide the same four values as the source
  details; 100% of invalid or incomplete QR cases are rejected before sign-in.
- **SC-003**: In all tested rejected-credential and unavailable-service cases, users
  receive distinct, actionable feedback and can retry or correct their details.
- **SC-004**: No tested QR payload, username, or password appears in application logs,
  diagnostics, or error messages.

## Assumptions

- First launch means the app has no completed login setup saved for the current user.
- The same username and password apply to both configured service URLs.
- Each of the four values is individually Base64-encoded from UTF-8 text. Base64 does
  not provide confidentiality; the QR code is treated as a credential-bearing secret.
- Manual entry and QR scanning lead to the same sign-in behavior and signed-in app
  experience.
- QR codes are created and supplied through an existing external workflow; this feature
  covers scanning them, not creating or displaying them.
- Existing authentication and session behavior is reused after setup succeeds.
