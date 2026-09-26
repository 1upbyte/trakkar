# Feature Specification: Map Home and People Overview

**Feature Branch**: `002-map-home`

**Created**: 2026-09-24

**Status**: Draft

**Input**: User description: "The main screen should open to a map. The map will show case ciruclar icons with every person's profile picture / initial. The default view will be zoomed out to fit everybody. If users are spread out more than roughly 2 miles, the zoom will cap there. Tapping on someone will zoom in on them and open a bottom model showing their name, current location, battery status, and last location update. Pressing back will close this modal and zoom back out to the original view. The map will also convert to a satelittle view when zoomed in enough. This threshold will be user configurable. Users who are close together will be grouped. Each grouped user will have their profile picture fully visible, even if a bit smaller. The map wil also show the name of custom saved locations on the map, similar to street names."

## Clarifications

### Session 2026-09-25

- Preserve the existing map provider integration: satellite imagery uses MapTiler's
  `satellite-v4` tiles, with the key read from the existing authenticated Traccar
  `/api/server` response attribute `trakkarMapTilerKey`. Do not require a Traccar server
  code change or embed the key in the app.
- The satellite switch threshold defaults to zoom level 19 for a new installation;
  user changes remain persisted. This is the switch threshold, not the launch camera
  zoom, which continues to fit people under FR-002.
- Reuse map tiles for up to 90 days with a 512 MB local cache limit. Cache identity
  must not include the MapTiler key.
- Reverse geocoding remains server-side through the existing authenticated Traccar
  geocoding service. The app does not call a third-party geocoder directly or hold its
  credentials.

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
- The server map configuration has no satellite key, the tile cache is full, or a
  cached tile has expired.
- Server-side reverse geocoding is disabled, unreachable, or returns no address.
- A map-related server request fails or the server connection is restored after failure.
- Location permission is not Always, precise accuracy is not granted, or the user updates
  either permission from the platform settings.
- The user changes the map view before selecting a person, then presses Back.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: The app MUST open to the map as its main screen after setup succeeds or
  after the user explicitly chooses Proceed Anyway for an unavailable service.
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
  threshold. A new installation MUST default this threshold to zoom level 19; changing
  the preference MUST NOT change the separate initial people-fit camera behavior.
- **FR-013**: Satellite map credentials MUST be read from the existing authenticated
  Traccar server configuration and MUST NOT be embedded in the app package or written
  to logs. A missing credential MUST leave the standard map usable and explain that
  satellite imagery is unavailable.
- **FR-014**: The app MUST cache map tiles locally, treat cached tiles as fresh for up
  to 90 days, and limit the tile cache to 512 MB. Cache identity MUST NOT include the
  satellite API key.
- **FR-015**: Reverse geocoding MUST use the existing authenticated server geocoding
  service. The app MUST NOT call a third-party geocoding provider directly or contain
  that provider's credentials. When server geocoding is unavailable, the map MUST use
  a matching saved-place name or coordinates as the location description.
- **FR-016**: Whenever a server connection fails, the app MUST show a red bar at the top
  reading “Connection to server failed” with a Retry button. Retry MUST retry the failed
  connection, and the bar MUST clear when the connection succeeds. This applies to map
  data, map configuration, and reverse-geocoding requests.
- **FR-017**: The app MUST show the shared red top permission bar with a Re-ask button
  whenever location access is not both Always and Precise. The bar MUST clear when the
  platform reports both permission requirements granted.

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
  crossings the map displays the corresponding map style; new installations default to
  zoom 19 without changing the people-fit launch framing.
- **SC-005**: In usability validation, at least 90% of users can identify a person and
  read their current status from the map and detail panel without assistance.
- **SC-006**: In 100% of tested cache scenarios, tile reuse respects the 90-day freshness
  period and 512 MB limit without including the API key in cache identity.
- **SC-007**: In 100% of tested address lookups, geocoding is requested through the
  server; when unavailable, the map shows a saved-place name or coordinates and does
  not contact a third-party geocoder directly.
- **SC-008**: In 100% of tested failed map-server requests, the red top connection bar
  and Retry button appear; retrying a recovered connection clears the bar.

## Assumptions

- “People” means people with a known current or last-reported location; users with no
  reported coordinates cannot be placed on the map.
- The approximately two-mile cap is treated as the maximum geographic extent used for
  automatic framing; the user can manually pan or zoom beyond it.
- “Current location” means the latest server-reported location. Its report time is shown
  so users can judge freshness.
- Saved-place names take precedence over reverse-geocoded descriptions when the person
  is within a named saved place.
- The satellite threshold is zoom level 19 by default and can be changed in Settings;
  this is separate from the initial camera fit.
- The existing Traccar server already exposes the authenticated map configuration and
  reverse-geocoding service; this feature does not require a server code or API change.
- Existing person, profile, battery, location, and saved-place information is available
  through the app's existing signed-in experience.
