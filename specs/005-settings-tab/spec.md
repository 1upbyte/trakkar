# Feature Specification: Settings Tab and App Reset

**Feature Branch**: `005-settings-tab`

**Created**: 2026-09-24

**Status**: Draft

**Input**: User description: "there shoulld be a final settings tab. The user can change their profile picture, display name, theme (system, light, dark). At the bottom they should see their current server details, and an option to reset the app."

## Clarifications

### Session 2026-09-24

- Q: What should Reset App clear? → A: Clear local app configuration only; do not delete any data.
- The Settings tab also owns the Map feature's satellite-switch threshold. New installs
  default to zoom level 19, user changes persist locally, and Reset App restores 19.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Update profile details (Priority: P1)

A user opens the final Settings tab to change their profile picture or display name and
sees those changes reflected across the app.

**Why this priority**: Profile identity is visible in the map and People views, so users
need a direct way to keep it current.

**Independent Test**: Change the profile picture and display name, reopen the Settings
tab, and verify the new identity appears in profile displays across the app.

**Acceptance Scenarios**:

1. **Given** the user is signed in, **When** they open the final bottom tab,
   **Then** it is the Settings tab and shows their current profile picture and name.
2. **Given** the user selects a new profile picture and confirms the change,
   **When** the upload and server save succeed, **Then** the picture is saved on the
   server and shown across the app.
3. **Given** the user enters a non-empty display name and saves it,
   **When** the update succeeds, **Then** the new name is shown across the app.
4. **Given** the user cancels a picture or name change,
   **When** they return to Settings, **Then** the previously saved value remains.

---

### User Story 2 - Choose an app theme (Priority: P1)

A user chooses System, Light, or Dark theme and configures when the map changes to
satellite imagery.

**Why this priority**: Theme choice makes the app comfortable to use in different
lighting conditions and according to personal preference.

**Independent Test**: Select each theme and a satellite threshold, then verify the
choices apply and remain after closing and reopening the app.

**Acceptance Scenarios**:

1. **Given** the user opens theme settings, **When** they view the choices,
   **Then** System, Light, and Dark are available.
2. **Given** the user chooses Light or Dark, **When** they return to any app tab,
   **Then** the selected appearance is applied throughout the app.
3. **Given** the user chooses System, **When** the device appearance changes,
   **Then** the app follows the device appearance.
4. **Given** the user opens map appearance settings, **When** they set the satellite
   threshold, **Then** the map preference is saved and used by the Map tab; a new
   installation starts at zoom level 19.

---

### User Story 3 - Review server details and reset the app (Priority: P2)

A user scrolls to the bottom of Settings to review the server connection details or
choose Reset App. The app explains the reset and asks for confirmation before acting.

**Why this priority**: Server details help users identify their active connection, and
the reset action provides a deliberate path to clear the current setup.

**Independent Test**: Verify the active server information at the bottom of Settings,
then confirm a reset and verify the app returns to setup while all server data remains.

**Acceptance Scenarios**:

1. **Given** the user is signed in, **When** they reach the bottom of Settings,
   **Then** they see the current client and manager server addresses and account name,
   without any password being displayed.
2. **Given** the user selects Reset App, **When** the confirmation is shown,
   **Then** its description explains what information will be cleared.
3. **Given** the reset confirmation is shown, **When** the user cancels,
   **Then** the current profile, theme, map appearance, server setup, and app state
   remain unchanged.
4. **Given** the user confirms reset, **When** the reset completes,
   **Then** local app configuration is cleared, the app returns to first-run setup, and
   all server-side data, including the uploaded profile picture, remains unchanged; the
   satellite threshold is restored to zoom level 19.

### Edge Cases

- The user cancels image selection or the chosen image cannot be saved.
- The user submits an empty display name.
- A profile update fails because the server cannot be reached.
- The device theme changes while System theme is selected.
- The active server details are unavailable or incomplete.
- The user starts a reset while a profile or theme update is still in progress.
- The app closes or is interrupted during a confirmed reset.
- The user confirms a reset while signed in to an account with profile and saved-place
  data; those server-side records must remain intact.
- The user has uploaded a profile picture; resetting local app configuration leaves
  that server-stored picture intact.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: The app MUST provide a Settings tab as the final destination in the
  bottom navigation.
- **FR-002**: Settings MUST show the current profile picture and display name and allow
  the user to change either value. A new profile picture MUST be uploaded to and saved
  on the server before the app reports success.
- **FR-003**: A saved profile picture or display-name change MUST be reflected anywhere
  the user's profile is shown in the app.
- **FR-004**: The app MUST reject an empty display name and preserve the previous value
  when a profile update fails or is canceled.
- **FR-005**: Settings MUST offer System, Light, and Dark theme choices.
- **FR-006**: Theme selection MUST apply throughout the app and remain selected after
  the app is closed and reopened. System theme MUST follow the device appearance.
- **FR-007**: At the bottom of Settings, the app MUST show the current client and manager
  server addresses and the signed-in account name when available.
- **FR-008**: Settings MUST NOT display the account password or other reusable secret
  as part of server details.
- **FR-009**: Settings MUST provide a Reset App action after the server details section.
- **FR-010**: The app MUST explain the effects of Reset App and obtain explicit
  confirmation before clearing any information.
- **FR-011**: Reset App MUST clear local app configuration, including saved sign-in and
  session details, configured server addresses, and the local theme preference, then
  return the app to first-run setup. It MUST NOT delete or modify the server account,
  profile, profile picture, saved places, tracking data, or other server-side
  information. It MUST NOT remove other user data beyond this local configuration.
- **FR-012**: Canceling reset confirmation MUST leave app and account data unchanged.
- **FR-013**: The app MUST report profile update or reset failures clearly and MUST NOT
  report a change as complete unless it succeeded.
- **FR-014**: Settings MUST allow the user to configure and persist the map's
  satellite-switch zoom threshold. A new installation MUST default to zoom level 19.
- **FR-015**: Confirmed Reset App MUST restore the satellite threshold preference to
  its new-installation default of zoom level 19.

### Key Entities *(include if feature involves data)*

- **User Profile**: The signed-in user's display name and optional server-stored image
  on their Traccar device.
- **Theme Preference**: The user's selected System, Light, or Dark appearance.
- **Map Appearance Preference**: The user's selected satellite-switch threshold.
- **Server Details**: The active service addresses and signed-in account identifier
  shown for reference without exposing a password.
- **Reset Request**: A user's request to clear app state, including its confirmation and
  the information within the confirmed reset scope.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: Users can change their profile picture and display name, and in 100% of
  successful update cases the new values appear anywhere their profile is shown.
- **SC-002**: Users can select each of the three themes, and in 100% of tested cases the
  selected theme is applied and retained after reopening the app.
- **SC-003**: In 100% of tested Settings views, current server addresses and account name
  appear at the bottom when available, and no password is shown.
- **SC-004**: In 100% of reset tests, no information is cleared before explicit
  confirmation, canceling leaves existing state unchanged, and confirming clears only
  the specified local configuration while preserving all server-side data.
- **SC-005**: At least 90% of usability-test participants can find profile, theme,
  server-detail, and reset controls without assistance.
- **SC-006**: Users can change and retain the satellite threshold; new installations
  and confirmed app resets use the default zoom level 19.

## Assumptions

- “Final Settings tab” means Settings appears after Map, People, and Places in the
  bottom navigation.
- The current server details are the configured client and manager server addresses
  and the signed-in account name; passwords and tokens are never displayed.
- Display-name changes use the existing signed-in profile. The profile picture is
  uploaded to the server-backed image for the signed-in user's device; both changes are
  reflected in Map and People views. Reset clears local setup only and leaves the
  server-stored picture intact.
- Theme preference is saved on the device; System means follow the device's current
  appearance setting.
- Reset requires confirmation, clears local app configuration only, and returns to
  first-run setup. Server-side account, profile image, saved-place, and tracking data
  remain.
