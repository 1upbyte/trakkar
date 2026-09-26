# Settings UI Contract

This contract describes observable behavior at the Flutter UI boundary; it adds no
new server endpoint.

## Navigation and content order

- Bottom navigation order is Map, People, Places, Settings.
- Settings shows profile image and display name controls, followed by System/Light/Dark
  theme selection, satellite threshold selection, server details, then Reset App.
- Server details include configured client URL, manager URL, and account name when
  available. Passwords, tokens, and other reusable credentials are never rendered.
- Missing server/account values use a clear unavailable state and do not break layout.

## Profile edits

- Image selection may be canceled without changing the saved image. Confirming uploads
  the image to the signed-in user's Traccar device and reports success only after the
  server saves it.
- Display name is trimmed and cannot be saved empty.
- During a save, show progress and prevent duplicate submission.
- On success, update shared identity presentation across all profile surfaces.
- On failure, preserve the last saved value and show actionable feedback.

## Theme selection

- Expose exactly System, Light, and Dark choices.
- Persist the selected choice locally and apply it app-wide.
- System follows current OS appearance; reset restores the new-install system default.

## Map appearance

- Expose a setting for the Map tab's satellite-switch zoom threshold.
- Default new installations to zoom level 19 and persist the user's selected threshold.
- Reset restores the satellite threshold to zoom level 19.

## Reset

- Reset App opens a confirmation that explains local sign-in/session details, server
  addresses, theme choice, and satellite threshold will be cleared or restored to their
  defaults. It does not say the server profile image will be removed.
- The confirmation explicitly states that server account/profile/profile-image/places/
  tracking data are not deleted.
- Cancel performs no mutation.
- Confirm stops SDK tracking and clears only the specified local configuration and SDK
  connection configuration. The SDK position queue and unrelated files are preserved.
- Route to first-run setup only after success. If clearing fails, show an error and
  leave the user in a recoverable state without claiming reset completed.
