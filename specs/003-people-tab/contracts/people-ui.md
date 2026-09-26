# People UI Contract

- Bottom-tab order places People after Map and before Places.
- Show every person authorized to the signed-in user after loading, alphabetically by
  name unless product requirements change.
- Each row shows name, portrait or initials, and current/last-known readable location.
- Missing location is explicitly unavailable; stale location shows its report time.
- A row with a location activates Map, opens the shared person detail panel, and uses
  the same content/action as tapping that marker. Back closes the panel and restores
  the map camera from before the row selection.
- A row without a location does not open a false position; explain that no map position
  is available.
- Tab transitions are continuous and preserve People scroll position and Map camera.
- Data refresh updates rows without forcing sign-out or rebuilding the tab shell.
