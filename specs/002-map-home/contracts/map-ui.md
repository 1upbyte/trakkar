# Map UI Contract

- Map is the signed-in landing tab.
- A person with a known position has a circular portrait/initial marker; a person with
  no position has no fabricated map coordinate and remains available in People.
- Initial framing includes known locations up to the automatic outward cap. Locations
  outside it remain reachable by manual pan/zoom.
- Crowded groups preserve each member's full identity and selectable action.
- Selecting a member zooms to them and opens the shared detail panel. Back closes it
  and restores the exact pre-selection camera snapshot.
- Detail shows name, readable location, battery/unknown, and last update time; stale
  information is labeled stale/last known.
- Saved place names render as legible contextual text, with decluttering based on area
  size and zoom.
- A new installation uses satellite threshold zoom 19. This preference is distinct
  from the initial people-fit camera and can be changed in Settings.
- Crossing the saved threshold switches from the standard OpenFreeMap style to
  MapTiler `satellite-v4`; if the existing server configuration has no MapTiler key,
  the standard map stays usable and satellite unavailability is surfaced.
- Readable addresses come from the authenticated server geocoder; if it is unavailable,
  show a matching saved-place name or coordinates.
- When a map-related server connection fails, show the shared red bar at the top with
  “Connection to server failed” and a Retry button. Retry the failed connection and clear
  the bar after success.
- Show the shared red permission bar with Re-ask when location access is not both Always
  and Precise; clear it after both permissions are granted.
