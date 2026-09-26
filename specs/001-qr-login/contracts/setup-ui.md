# Setup UI Contract

- Before first successful setup, present Scan QR and Enter Details choices.
- Request camera access only after Scan QR is selected. Denial or scan cancellation offers
  retry and manual entry.
- Parse and validate a scan before showing a destination review. Invalid input displays
  a safe explanation and does not submit credentials.
- The review shows normalized client/manager destinations and explains that Base64 is
  not encryption and the QR must be kept private. Password and raw QR text are not shown.
- Continue requires explicit confirmation. Manual and QR details use the same submit
  action and authentication behavior.
- Invalid/missing form fields stay editable; errors distinguish rejected credentials
  from unavailable service without echoing secrets.
- Never display scanner/parser exception text verbatim.
