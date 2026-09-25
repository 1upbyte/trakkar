# Feature Specification: People Tab and Map Navigation

**Feature Branch**: `003-people-tab`

**Created**: 2026-09-24

**Status**: Draft

**Input**: User description: "There should be a 'people' tab separate from the map tab that will show a list of everybody along with their current location, profile picture, name. Tapping on somebody should open their location/modal on the map, same action as tapping their profile picture on the map. The transitions between the tabs at the bottom should be smooth."

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Browse everyone in the People tab (Priority: P1)

A user opens the People tab to see everyone in one list, with each person's profile
picture, name, and current or most recently reported location.

**Why this priority**: The list gives users a direct way to find someone without
searching across map markers.

**Independent Test**: Open the People tab with multiple people and verify each person
appears with their identity and location information.

**Acceptance Scenarios**:

1. **Given** the user is signed in, **When** they select the People tab,
   **Then** the app shows a list of everyone available to that user.
2. **Given** a person has a profile picture, **When** their row is displayed,
   **Then** the profile picture appears with their name and current location.
3. **Given** a person has no profile picture or current location,
   **When** their row is displayed, **Then** an initial-based avatar and a clear
   unavailable-location label appear rather than missing or misleading information.

---

### User Story 2 - Open a person's map details from the list (Priority: P1)

A user selects a person in the People tab and is taken to the Map tab, where that
person's location and detail panel open with the same behavior as selecting their map
marker.

**Why this priority**: List and map selection should be interchangeable ways to inspect
the same person.

**Independent Test**: Select a person from the People tab and compare the resulting map
zoom and detail panel with the result of selecting that person's marker directly.

**Acceptance Scenarios**:

1. **Given** the People tab is showing a person with a known location, **When** the user
   taps that person, **Then** the Map tab opens, zooms to the person, and shows the same
   detail panel as direct map selection.
2. **Given** a person has no known location, **When** the user taps their row,
   **Then** the app explains that their location is unavailable and does not present a
   false map position.
3. **Given** the person detail panel opened from the People tab, **When** the user
   presses Back, **Then** the panel closes and the map returns to its pre-selection view.

---

### User Story 3 - Move smoothly between bottom tabs (Priority: P2)

A user moves between the Map and People tabs and sees a continuous transition that
preserves the context of each tab.

**Why this priority**: Smooth navigation keeps the primary app views connected and avoids
making tab changes feel disruptive.

**Independent Test**: Switch repeatedly between the Map and People tabs while the map is
positioned and the list is scrolled; verify transitions are continuous and both views
retain their context.

**Acceptance Scenarios**:

1. **Given** either bottom tab is active, **When** the user selects the other tab,
   **Then** the new tab becomes active with a continuous transition and no blank or
   unintended intermediate screen.
2. **Given** the user has moved the map or scrolled the People list,
   **When** they switch to the other tab and return, **Then** each view retains its
   previous context.

### Edge Cases

- The People list is empty or still loading.
- A person has no profile picture, no reported location, or a stale last location.
- The user's location data changes while the People list is open.
- The selected person's row is tapped repeatedly while the map is opening.
- The user switches tabs while a map detail panel is open.
- The app is interrupted during a tab transition.
- A person is visible in the People list but their location is outside the map's current
  viewport.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: The app MUST provide a People tab separate from the Map tab in the bottom
  navigation.
- **FR-002**: The People tab MUST list every person available to the signed-in user.
- **FR-003**: Each person row MUST show the person's name, profile picture, and current
  location when available.
- **FR-004**: If a person has no profile picture, the app MUST show their initials in
  its place. If their current location is unavailable, the app MUST say so clearly.
- **FR-005**: Location descriptions MUST prefer a matching custom saved-location name,
  then a readable address, and then coordinates when those are the best available data.
- **FR-006**: The app MUST identify stale location data with its last update time and
  MUST NOT present it as current.
- **FR-007**: Selecting a person with a known location in the People tab MUST activate
  the Map tab, zoom to that person, and open the same detail panel and content as
  selecting that person's map marker.
- **FR-008**: Selecting a person without a known location MUST explain that no map
  position is available and MUST NOT open the map as though a location were known.
- **FR-009**: Pressing Back from a detail panel opened from the People tab MUST close the
  panel and restore the map view that existed before the person was selected.
- **FR-010**: Switching between bottom tabs MUST use a continuous visual transition with
  no blank screen or unrelated intermediate destination.
- **FR-011**: Switching tabs MUST preserve the map position and the People list's scroll
  position when the user returns to each tab.
- **FR-012**: The People list MUST reflect updated person locations and profile details
  without requiring the user to sign out and back in.

### Key Entities *(include if feature involves data)*

- **Person**: A person available to the signed-in user, with a name and optional profile
  image.
- **Person Location**: The person's latest known location and the time it was reported.
- **People List Row**: The person's visual entry in the People tab, including identity
  and location description.
- **Bottom Tab**: A top-level destination, including Map and People, with its own retained
  view context.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: 100% of people available to the signed-in user appear in the People list
  after loading completes.
- **SC-002**: In 100% of tested list selections with a known location, the app opens the
  same map detail experience as direct selection of that person's map marker.
- **SC-003**: In 100% of tested cases with missing or stale location data, the list
  clearly identifies its status and does not imply the location is current.
- **SC-004**: In usability validation, at least 90% of users can find a person and open
  their map details from the People tab without assistance.
- **SC-005**: In 100% of tested tab changes, the app shows no blank or unintended
  intermediate screen and restores each tab's previous map or list position.

## Assumptions

- “Everybody” means all people the signed-in user is authorized to see in the app.
- People are ordered alphabetically by name unless the user later specifies another
  order.
- A person's current location means their latest server-reported position; when it is
  stale, its update time is shown and it is described as last known.
- A person without a known location remains visible in the list but cannot be opened at
  a map position.
- “Smooth” means the tab change is continuous, does not show a blank/intermediate screen,
  and preserves each tab's view state; a specific animation duration is not required.
- This feature reuses the existing map person-selection details and location data.
