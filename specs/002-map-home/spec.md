# Feature Specification: Map Home and People Overview

**Feature Branch**: `002-map-home`

**Created**: 2026-09-24

**Status**: Draft

**Input**: User description: "The main screen should open to a map. The map will show case ciruclar icons with every person's profile picture / initial. The default view will be zoomed out to fit everybody. If users are spread out more than roughly 2 miles, the zoom will cap there. Tapping on someone will zoom in on them and open a bottom model showing their name, current location, battery status, and last location update. Pressing back will close this modal and zoom back out to the original view. The map will also convert to a satelittle view when zoomed in enough. This threshold will be user configurable. Users who are close together will be grouped. Each grouped user will have their profile picture fully visible, even if a bit smaller. The map wil also show the name of custom saved locations on the map, similar to street names."

## User Scenarios & Testing *(mandatory)*

### User Story 1 - See people on the map (Priority: P1)

When a user opens the app, they see a map centered and zoomed to show the people with
known locations. Each person is represented by a circular marker containing their
profile picture, or their initials if no picture is available. Nearby people are grouped
so their markers remain identifiable.

**Why this priority**: The map is the primary screen and gives users an immediate view
of where their people are.

**Independent Test**: Open the map with several people at different and nearby
locations, then verify the initial framing, circular markers, and grouped markers.

**Acceptance Scenarios**:

1. **Given** people have reported locations, **When** the user opens the main screen,
   **Then** the map frames their locations within the approximately two-mile auto-fit
   limit.
2. **Given** a person's profile has an image, **When** their marker appears,
   **Then** the image is shown inside a circular marker.
3. **Given** a person has no profile image, **When** their marker appears,
   **Then** their initials appear inside the circular marker.
4. **Given** several people are close together on the map, **When** the map is shown,
   **Then** they are grouped and every group member's full image or initials remain
   visible and individually identifiable, scaled down as needed.

---

### User Story 2 - Inspect a person's status (Priority: P1)

A user taps a person on the map to see that person's name, current location, battery
status, and the time of their last location update. The map zooms in on the selected
person. When the user presses Back, the details close and the map returns to its view
from before selection.

**Why this priority**: The map is most useful when users can quickly inspect a person
without losing their shared overview.

**Independent Test**: Tap a person marker, verify the detail panel and zoom, then press
Back and verify the panel closes and the prior map view is restored.

**Acceptance Scenarios**:

1. **Given** the map is showing people, **When** the user taps a person, **Then** the map
   zooms in and a bottom panel shows the person's name, current location, battery
   status, and last location update.
2. **Given** the person detail panel is open, **When** the user presses Back,
   **Then** the panel closes and the map returns to the zoom and position it had before
   the person was selected.
3. **Given** a person's battery or location detail is unavailable, **When** the panel is
   shown, **Then** the unavailable value is identified as unknown or unavailable rather
   than shown as current information.
4. **Given** a person is represented inside a group marker, **When** the user selects
   that person, **Then** the person can be individually selected and inspected.

---

### User Story 3 - Read map context and choose satellite detail (Priority: P2)

A user sees custom saved location names as map labels alongside geographic context. As
the user zooms in, the map switches to satellite imagery at a threshold the user can
adjust in settings.

**Why this priority**: Place names help users orient themselves, while satellite imagery
provides more detail when users inspect a close area.

**Independent Test**: View saved locations at different map scales, then change the
satellite threshold and verify the map style changes when that threshold is crossed.

**Acceptance Scenarios**:

1. **Given** custom saved locations are visible in the map area, **When** the map is
   displayed at a useful scale, **Then** their names appear as text labels integrated
   with the map context.
2. **Given** the map is below the user's satellite threshold, **When** the map is shown,
   **Then** the standard map view is used.
3. **Given** the map reaches or passes the user's satellite threshold, **When** the map
   is shown, **Then** satellite imagery is used.
4. **Given** the user changes the satellite threshold, **When** the map is zoomed across
   the new threshold, **Then** the map style follows the updated preference.

### Edge Cases

- No people have reported locations, or a person has never reported a location.
- A person's last known location is stale, or their battery status is unavailable.
- A profile has no picture, or the picture cannot be loaded.
- People are clustered so tightly that the group marker must shrink member images.
- People are spread farther apart than the automatic framing limit.
- The selected person's location changes while their detail panel is open.
- A saved place is too small or too close to another label to display legibly.
- The selected map style or satellite imagery is unavailable.
- The user changes the map view before selecting a person, then presses Back.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: The app MUST open to the map as its main screen after setup is complete.
- **FR-002**: The initial map view MUST frame people with known locations, while limiting
  automatic zoom-out to an extent of approximately two miles. When their spread exceeds
  that limit, the app MUST keep the capped view; users MAY pan or zoom to reach people
  outside it.
- **FR-003**: Each person with a known location MUST have a circular map marker containing
  their profile picture, or their initials when no picture is available.
- **FR-004**: The app MUST group people whose map markers are close enough to crowd or
  overlap, and MUST keep every group member's full picture or initials visible in an
  individual circular sub-marker and individually selectable, shrinking them as needed.
- **FR-005**: Selecting a person MUST zoom the map to that person and open a bottom detail
  panel with their name, current location, battery status, and last location update.
- **FR-006**: The current-location detail MUST prefer the person's custom saved location
  name when applicable; otherwise it MUST show the best available readable location,
  such as an address or coordinates.
- **FR-007**: Pressing Back while the detail panel is open MUST close the panel and restore
  the map position and zoom that were active immediately before selection.
- **FR-008**: The detail panel MUST identify unavailable or stale location and battery
  information so that it is not mistaken for current status.
- **FR-009**: The map MUST display custom saved location names as text labels integrated
  with map context, rather than using prominent pins or outlines as the only indication.
- **FR-010**: Saved-location label visibility MUST account for the represented area's
  size and current map scale so labels remain legible and do not obscure the map.
- **FR-011**: The map MUST switch from its standard view to satellite imagery when the
  current zoom reaches the user's configured threshold.
- **FR-012**: Users MUST be able to change and retain their preferred satellite-switch
  threshold.

### Key Entities *(include if feature involves data)*

- **Person Location**: A person's most recent known coordinates, report time, battery
  status, name, and optional profile image.
- **Person Marker**: The circular visual representation of one person on the map.
- **People Group**: A set of nearby people presented together while keeping each member
  visually identifiable and selectable.
- **Saved Location**: A custom named area or point whose name can be displayed as map
  context and used to describe a person's current location.
- **Satellite Threshold Preference**: The user's selected zoom point at which the map
  changes to satellite imagery.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: In 100% of tested map openings, every available person location within the
  approximately two-mile framing limit is visible in the initial view.
- **SC-002**: In 100% of tested person selections, the bottom panel shows all four
  requested details and Back restores the exact pre-selection map view.
- **SC-003**: In 100% of tested crowded groups, each member remains individually visible
  and selectable without cropped or hidden profile images/initials.
- **SC-004**: Users can change the satellite threshold, and in 100% of tested threshold
  crossings the map displays the corresponding map style.
- **SC-005**: In usability validation, at least 90% of users can identify a person and
  read their current status from the map and detail panel without assistance.

## Assumptions

- “People” means people with a known current or last-reported location; users with no
  reported coordinates cannot be placed on the map.
- The approximately two-mile cap is treated as the maximum geographic extent used for
  automatic framing; the user can manually pan or zoom beyond it.
- “Current location” means the latest server-reported location. Its report time is shown
  so users can judge freshness.
- Saved-place names take precedence over reverse-geocoded descriptions when the person
  is within a named saved place.
- The initial satellite threshold is a close-in map scale selected by the product; users
  can change it. A numeric default can be chosen during planning or design review.
- Existing person, profile, battery, location, and saved-place information is available
  through the app's existing signed-in experience.
