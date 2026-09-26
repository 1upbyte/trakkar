# Phase 0 Research: QR Login and First-Run Setup

**Research date**: 2026-09-25

## QR wire format and compatibility

**Decision**: Parse the complete scanner string as standard Base64 with padding, decode
it once as strict UTF-8, then split the decoded text on semicolons. The grammar is
exactly four non-empty fields in this order: `user;password;clienturl;managerurl`;
`user` maps to username. Reject any payload that does not yield exactly four fields.
Because this grammar has no escaping, a semicolon in a value makes the payload invalid.

**Rationale**: The user specified the exact delimiter, order, and that Base64 applies to
the joined string. Strict single-pass decoding followed by an exact four-field check
avoids interpreting malformed or extra fields as credentials.

**Alternatives considered**: Base64-encode each value separately or use a JSON envelope.
Rejected because they differ from the specified wire format. Escaping semicolons could
support a wider set of field contents but would require a different producer grammar.

Sources: [RFC 4648](https://www.rfc-editor.org/rfc/rfc4648.html),
[Flutter QR scanner package](https://pub.dev/packages/mobile_scanner).

## Credential handling and URLs

**Decision**: Parse and validate entirely before authentication; never submit on scan.
Show normalized client and manager destinations, mask/avoid re-displaying the password,
and submit only after affirmative confirmation. Validate absolute HTTP(S) URLs with a
host and reject malformed syntax and embedded URL credentials. Prefer HTTPS; if plain
HTTP must be supported for a self-hosted deployment, clearly disclose the unencrypted
transport and obtain confirmation before sending the password. Keep parser, transport,
and auth errors generic and secret-free.

**Rationale**: Base64 represents bytes as text but does not provide secrecy. URLs and
scanner exceptions can also contain sensitive material. Server authentication remains
the authority; the QR flow should only seed the already established session mechanism.

**Alternatives considered**: Treat Base64 as encryption or log raw scanner output for
debugging. Rejected because either exposes reusable credentials.

Sources: [RFC 4648](https://www.rfc-editor.org/rfc/rfc4648.html),
[OWASP Logging Cheat Sheet](https://cheatsheetseries.owasp.org/cheatsheets/Logging_Cheat_Sheet.html),
[Traccar API](https://www.traccar.org/traccar-api/).

## Scanner and platform permissions

**Decision**: Use a Flutter scanner plugin supporting Android and iOS camera APIs; ask
for camera permission only after the user chooses Scan QR. Denial, revocation, cancel,
and scanner failure return to retry or manual entry. Do not request photo-library access
unless gallery scanning is separately introduced.

**Rationale**: Camera access is only needed for one user-selected setup route, and both
platforms have native permission declarations and runtime authorization requirements.

Source: [mobile_scanner package configuration](https://pub.dev/packages/mobile_scanner),
[Flutter camera recipe](https://docs.flutter.dev/cookbook/plugins/picture-using-camera).

## Authentication and session

**Decision**: Route both QR and manual LoginDetails to the app's existing authenticated
Traccar session flow. Store only successful session/configuration in secure local
storage; do not create a new auth contract in this feature.

**Rationale**: The Traccar API supports established session/auth mechanisms, but this
spec does not select one. Existing signed-in behavior is explicitly assumed to be reused.

Source: [Traccar API](https://www.traccar.org/traccar-api/) and
[API reference](https://www.traccar.org/api-reference).

## Mobile app identity

**Decision**: Use `com.1upbyte.trakkar` as the shared identifier for Android and iOS
builds.

**Rationale**: A consistent identifier keeps both platform builds associated with the
same app identity and gives the restored Flutter host projects one explicit value to
configure.
