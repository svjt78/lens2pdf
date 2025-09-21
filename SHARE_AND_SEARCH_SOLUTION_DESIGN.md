# Share & Search Enhancements — Solution Design

## Goals
- Allow every share surface to include both the generated PDF and structured metadata extracted from the document.
- Deliver a consistent share experience across generic share sheets and targeted channels (Mail, SMS, WhatsApp, AirDrop) with graceful fallbacks.
- Add inline library search that filters the grid/list of scans by any extracted datum (receipts and IDs) plus filenames.

## Share Payload Strategy
- Introduce a reusable `ReceiptSharePayload`-style helper inside `mobile_app/lib/services/share_service.dart` that packages:
  - The PDF `File` reference.
  - A lazily generated JSON file describing the document (receipt totals, vendor, purchase date, payment, plus ID-specific fields such as `documentType`, redaction state, watermark settings).
  - A plain-text summary paragraph tailored to the document type (e.g., “Receipt · Vendor: … · Total: …” or “ID · Type: DL · Redactions: …”).
- JSON is the canonical structured attachment; CSV support is intentionally omitted per product decision.
- When metadata is missing (legacy files), the helper falls back to the PDF-only list while still emitting a summary string so the share sheets show useful context.
- Temporary JSON files live under the app cache directory and are deleted immediately after the share intent resolves (best effort via `try/finally`).

## Dart Integration
- Extend `ShareService` APIs to accept the payload object and emit multiple `XFile`s when calling `Share.shareXFiles`.
- Preserve targeted method-channel helpers (`shareEmail`, `shareSms`, `shareWhatsApp`, `shareAirdrop`) but forward the summary string and metadata file path/mime type to the iOS runner.
- Update callers:
  - `ExportScreen` (`mobile_app/lib/screens/export_screen.dart`) loads receipt/ID metadata before showing the share sheet and builds the payload once.
  - `LibraryScreen` (`mobile_app/lib/screens/library_screen.dart`) resolves metadata lazily when the user taps “Share” on an existing item.
- Ensure `PdfService.buildPdf` continues to persist companion metadata JSON via `LibraryRepository.saveMetadata` so share payloads remain in sync after export.

## iOS Method-Channel Handling
- Modify `mobile_app/ios/Runner/AppDelegate.swift` handlers to accept `summaryText`, `metadataPath`, and `metadataMime`.
- Channel methods attach both the PDF and JSON when presenting `MFMailComposeViewController`, `MFMessageComposeViewController`, or `UIActivityViewController` (WhatsApp/AirDrop).
- The summary string is injected into the email body and SMS text field; WhatsApp/AirDrop receive it as a separate text activity item.
- When an attachment type is unsupported (e.g., SMS without attachment capability), the handler falls back to the generic share sheet carrying the same activity items.

## Library Search Experience
- Embed a search bar directly in the library app bar (using `SearchAnchor` or a custom `TextField`) positioned above the grid/list of scans.
- Convert the library presentation to a responsive grid while keeping existing list behavior on narrow widths if needed.
- `LibraryRepository` exposes a filtered stream:
  - Normalize tokens for filenames, vendor, purchase date (both formatted and ISO-like strings), total amounts (currency + numeric), payment method, card last four, and ID metadata (document type, expiry, watermark style, redaction status).
  - Matching is case-insensitive substring; numeric queries match sanitized amount text (e.g., `$12.34` and `12.34`).
- UI states: loading (spinner), empty library message, and “No matches for "query"” with a clear button.
- Optional value-add (stretch): highlight hits in titles/subtitles using `RichText` and mention the metadata field (e.g., “Vendor match”).

## Data & Persistence Considerations
- Continue writing receipt metadata immediately after PDF creation; extend the schema to store any ID-specific fields already produced by the capture flow so share/search stay aligned.
- Plan a lazy upgrade path: whenever a file without metadata is shared or viewed, attempt to generate minimal metadata (e.g., filename + created date) to populate the JSON attachment.
- Keep JSON lightweight (<10 KB) to avoid share limitations, using camelCase keys that match existing data models.

## Testing Plan
- **Dart unit tests** covering payload construction (presence/absence of metadata, summary formatting for receipts vs IDs) and search filtering edge cases (vendor casing, amount parsing, ID-only fields).
- **Swift unit/UI tests** for the AppDelegate share channel to assert both attachments are added when metadata exists and that fallbacks execute when services are unavailable.
- **Widget tests** for the library screen verifying search state transitions and empty-result messaging.
- Run `make analyze` and `make test` before shipping; add golden tests if the library UI changes significantly.

## Documentation & Follow-Up
- Update `SPEC.md` and `IMPLEMENTATION_PLAN.md` after implementation to reflect JSON + summary sharing and inline search requirements.
- Note in release notes that SMS now includes a summary text and will attach metadata when the platform allows it.
- Coordinate with QA to capture share flows (Mail, Messages, WhatsApp, AirDrop) and search scenarios across receipts and IDs.

