# External QR Payload Contract

## Wire format

The QR scanner returns one standard RFC 4648 Base64 string. Trim leading and trailing
whitespace from the scanned string before decoding; reject whitespace anywhere within
the remaining Base64 payload. Decode the complete trimmed string once to UTF-8. The
decoded text MUST contain exactly four non-empty fields, in this order, separated by
literal semicolons:

```text
user;password;clienturl;managerurl
```

`user` is the login username. The entire delimited string is Base64-encoded as one
payload; fields are not Base64-encoded individually. Use the standard Base64 alphabet
with canonical padding. Reject invalid Base64, invalid UTF-8, missing/empty fields, or
anything that splits into other than exactly four fields. The format has no escaping,
so semicolons are forbidden inside all four values. Manual entry remains available for
values that cannot be represented by this grammar.

## Processing and privacy

- Parse locally; parsing has no network side effects.
- Validate both decoded URLs as absolute supported service URLs before preview.
- Show client and manager destinations and require confirmation before authentication.
- Do not display or log the raw QR text, password, or decoded payload.
- Explain that Base64 is encoding, not encryption, and the QR code must be kept private.
- Clear transient payload/credential values after cancellation or completion according
  to the app's secure-memory/session practices.

## Interoperability fixtures

Maintain golden tests generated from the agreed grammar using non-secret test values.
Include valid payloads with surrounding whitespace, rejection of internal whitespace,
malformed Base64, invalid UTF-8, missing/empty/additional fields, semicolon-containing
values, invalid URLs, and valid strings with non-ASCII UTF-8. QR generation and display
remain outside this app feature.
