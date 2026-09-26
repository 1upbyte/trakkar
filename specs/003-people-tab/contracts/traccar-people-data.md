# Traccar People Data Contract

- Use the app's authenticated Traccar API/session client and server authorization.
- Build the shared people projection from accessible device/profile records and latest
  position records; preserve the app-specific person-to-device identity mapping.
- Prefer the already configured live update channel. Do not create an additional
  location uploader or high-frequency polling path.
- Read a position's server-provided address when available; use the shared saved-place
  containment resolver before it. Show coordinates only as a final fallback.
- Do not log precise coordinates or historical tracks.

References: [Traccar API](https://www.traccar.org/api-reference) and
[Traccar API usage](https://www.traccar.org/traccar-api/).
