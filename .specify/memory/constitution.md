<!--
Sync Impact Report
Version change: uninitialized template -> 1.0.0
Modified principles: none; this is the first completed constitution.
Added sections: Additional Constraints; Development Workflow; Governance rules.
Removed sections: none.
Follow-up TODOs: Confirm the original ratification date.
-->

# Trakkar Constitution

## Core Principles

### I. Server-Authoritative Traccar Integration
Trakkar MUST use the Traccar SDK for device location tracking and reporting. The Traccar
server is authoritative for shared devices, positions, and server-managed data. Client
features MUST use documented server APIs and authenticated sessions, and MUST NOT create
a parallel tracking engine or treat local state as the authoritative shared record. Map
and geocoding provider configuration MUST come from authenticated server configuration;
provider secrets MUST NOT be embedded in source code, committed configuration, or logs.

### II. Location Privacy and Data Minimization
The app MUST request location permissions only for user-visible tracking features and
respect the user's permission and tracking choices. It MUST collect and transmit only the
location data needed for those features, protect credentials and sensitive location data,
and avoid logging precise location histories or secrets. Location use and background
behavior MUST be disclosed in context so users can make informed choices.

### III. Battery-Aware and Honest Tracking
Tracking MUST use SDK-supported platform behavior and account for operating-system
background limits. Foreground updates MAY be more responsive; background work MUST use a
lower duty cycle unless an active user-selected feature requires otherwise. The app MUST
handle denied permissions, interruptions, and stale data explicitly, and MUST NOT promise
continuous tracking when the platform or server cannot provide it.

### IV. Clear and Accessible Map Experiences
Map, device, and saved-place information MUST remain distinguishable and understandable
across supported screen sizes and themes. Controls MUST expose clear labels and feedback,
and saved places and in-progress geometry MUST have visually distinct states. Map labels
and overlays MUST remain legible at relevant zoom levels. Features MUST preserve usable
non-map navigation for managing devices and places.

### V. Verifiable Changes and Failure Handling
Changes to tracking, server contracts, location permissions, background work, geometry,
or notifications MUST include focused automated coverage for their observable behavior
when the code can be tested. Reviews MUST consider error, offline, permission, and
app-lifecycle states affected by the change. User-facing failures MUST be surfaced with
actionable feedback; silent data loss or misleading success states are not acceptable.

## Additional Constraints

- The client MUST NOT add Google Maps SDK configuration or require a client-held map
  provider key. Required map and geocoding configuration MUST be obtained through the
  authenticated server flow.
- Credentials, provider keys, and precise location histories MUST NOT be checked into
  source control or included in diagnostic output.
- Server-backed behavior MUST remain compatible with the Traccar API and SDK contracts.
  Any intentional contract dependency or limitation MUST be documented with the feature.
- Platform-specific location and notification behavior MUST follow the permission and
  lifecycle rules of the supported mobile operating systems.

## Development Workflow

- Feature specifications and implementation reviews MUST identify affected server
  contracts, permissions, privacy implications, battery costs, and supported platforms.
- Changes to tracking or background execution MUST be checked in both foreground and
  background states, including denied or revoked permission and interrupted-session
  behavior where applicable.
- Changes to map, named-place, or notification behavior MUST include focused checks for
  the affected rendering, geometry, and user preference behavior.
- Reviewers MUST distinguish automated test results from manual device or live-server
  verification and document any required verification that could not be performed.

## Governance

Amendments MUST include a rationale and identify affected principles, constraints, and
active specifications. A project maintainer MUST approve an amendment before it is
adopted. Changes that alter existing obligations or compatibility expectations MUST
include a migration plan. Every implementation review MUST check compliance with this
constitution; any exception MUST be documented with its scope and rationale and approved
by a maintainer. This constitution takes precedence over conflicting project guidance.

Versioning follows semantic versioning: MAJOR for incompatible changes to principles or
governance, MINOR for new principles or materially expanded obligations, and PATCH for
clarifications and non-semantic edits. The last-amended date changes whenever this
constitution changes.

**Version**: 1.0.0 | **Ratified**: 2026-09-24
**Last Amended**: 2026-09-24
