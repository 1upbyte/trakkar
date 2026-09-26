# Feature Specification: Places Tab and Saved Place Management

**Feature Branch**: `004-places-tab`

**Created**: 2026-09-24

**Status**: Draft

**Input**: User description: "There should be places tab that allows the user to see all saved places. They should be able to add one as well as delete any of them, with confirmation before they delete. For adding, they should be able to choose 'auto' mode that uses building data, or manually move the corners. After, they will provide a name."

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Browse and manage saved places (Priority: P1)

A user opens the Places tab to see all saved places, add another place, or delete a place
they no longer need. Deletion requires confirmation.

**Why this priority**: The tab is the central place for users to manage saved locations
and their names.

**Independent Test**: Open the Places tab with several saved places, verify they are all
listed, then confirm and cancel separate delete attempts.

**Acceptance Scenarios**:

1. **Given** the user has saved places, **When** they open the Places tab,
   **Then** every saved place appears with its name.
2. **Given** the user chooses to delete a saved place, **When** the delete confirmation
   appears, **Then** the place remains saved until the user confirms.
3. **Given** a delete confirmation is open, **When** the user cancels,
   **Then** the place remains in the list and no deletion occurs.
4. **Given** the user confirms deletion, **When** the deletion succeeds,
   **Then** the place is removed from the list and saved places on the map.

---

### User Story 2 - Add a place using building data (Priority: P1)

A user starts adding a place, chooses Auto mode, selects a building with available
building data, reviews its boundary, gives the place a name, and saves it.

**Why this priority**: Auto mode lets users create a place boundary quickly from an
existing building outline.

**Independent Test**: Choose Auto mode for a mapped building, review the boundary, enter
a name, save it, and verify it appears in the Places list and on the map.

**Acceptance Scenarios**:

1. **Given** the user chooses to add a place, **When** the app asks for a creation mode,
   **Then** it offers Auto and Manual.
2. **Given** Auto mode and building data are available, **When** the user selects a
   building, **Then** the app previews a boundary based on that building's outline.
3. **Given** the user accepts the previewed boundary and enters a name,
   **When** they save the place, **Then** it appears in the Places list and as a named
   place on the map.
4. **Given** no building data is available for the chosen area, **When** the user uses
   Auto mode, **Then** the app explains this and offers Manual mode.

---

### User Story 3 - Add a place by moving its corners (Priority: P1)

A user starts adding a place, chooses Manual mode, positions or moves the boundary's
corners on the map, provides a name, and saves the resulting area.

**Why this priority**: Manual editing lets users define areas when building data is
missing or does not match the place they want to save.

**Independent Test**: Create a manual boundary by adjusting its corners, name it, save
it, and verify the saved boundary and name are available afterward.

**Acceptance Scenarios**:

1. **Given** the user chooses Manual mode, **When** the map editor opens,
   **Then** they can place or move boundary corners to define the desired area.
2. **Given** the boundary is incomplete or invalid, **When** the user tries to continue,
   **Then** the app explains what needs correction and does not save the place.
3. **Given** the user has a valid boundary, **When** they enter a non-empty name and save,
   **Then** the new place appears in the Places list and on the map.
4. **Given** the user cancels before saving, **When** they leave the add flow,
   **Then** no new saved place is created.

### Edge Cases

- No saved places exist yet.
- Building data is missing, incomplete, or describes more than one nearby building.
- The building boundary does not match the area the user wants to save.
- The user tries to save without a name or with a boundary too small to be valid.
- A place name duplicates an existing place name.
- The user cancels the add flow after changing a boundary.
- Saving or deleting fails because the server cannot be reached.
- A place is deleted while its label is visible on the map.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: The app MUST provide a Places tab where the user can view every saved
  place available to their account.
- **FR-002**: Each saved place in the list MUST show its name and provide access to its
  delete action.
- **FR-003**: The app MUST ask the user to choose Auto or Manual mode when they start
  adding a place.
- **FR-004**: In Auto mode, the app MUST use available building data to identify a
  building boundary and MUST preview that boundary before saving.
- **FR-005**: If Auto mode cannot find usable building data, the app MUST explain that
  no boundary is available and offer the user a way to continue in Manual mode.
- **FR-006**: In Manual mode, the app MUST let the user place or move boundary corners
  on the map to define the saved area.
- **FR-007**: Before saving a place from either mode, the app MUST require a non-empty
  name and a valid boundary, and MUST show the user the boundary they are saving.
- **FR-008**: After a place is saved, the app MUST show it in the Places list and display
  its name as map context.
- **FR-009**: Before deleting a place, the app MUST show a confirmation that identifies
  the place by name.
- **FR-010**: Canceling delete confirmation MUST leave the place and its map display
  unchanged; confirming MUST remove the place from the saved list and map after deletion
  succeeds.
- **FR-011**: If saving or deleting fails, the app MUST explain that the change was not
  completed and keep the list consistent with the saved server state.
- **FR-012**: Canceling place creation before save MUST discard the unsaved boundary
  without creating a saved place.

### Key Entities *(include if feature involves data)*

- **Saved Place**: A user-named area with a boundary that appears in the Places list and
  provides map context.
- **Place Boundary**: The geographic outline selected from building data or defined by
  the user moving corners in Manual mode.
- **Place Creation Draft**: An unsaved boundary and selected mode that can be reviewed,
  named, saved, or discarded.
- **Delete Confirmation**: A user decision to keep or remove one named saved place.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: 100% of saved places available to the user's account appear in the Places
  list after loading completes.
- **SC-002**: In 100% of tested successful Auto and Manual creation flows, the saved
  place has the confirmed boundary and entered name and appears in both the list and map.
- **SC-003**: In 100% of tested deletion flows, a place is removed only after explicit
  confirmation; canceling leaves it unchanged.
- **SC-004**: In 100% of tested missing-building-data cases, users are told Auto mode
  cannot define a boundary and can continue in Manual mode.
- **SC-005**: In usability validation, at least 90% of users can add a named place or
  delete a selected place without assistance.

## Assumptions

- “All saved places” means places available to the signed-in user's account.
- Auto mode lets the user select a mapped building and uses its available building
  outline as the initial boundary; the user reviews it before saving.
- Manual mode defines a polygon by placing or moving its corners. Existing saved places
  of other supported boundary shapes remain visible in the list.
- A non-empty name is required; duplicate names are allowed unless the user later asks
  for uniqueness.
- Saved place data remains server-authoritative and successful changes update the map's
  named-place labels.
