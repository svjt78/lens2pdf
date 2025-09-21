# Flutter Iteration 1 Implementation Plan

This plan outlines the Flutter-side work needed to satisfy the iteration 1 scope for the mobile app while deferring native-only components. The goals are: enriched library management (metadata editing, filters), CSV export, and share profiles, all integrated with existing services without regressing current functionality.

## Scope Summary
- Extend metadata support so receipts store editable vendor/date/total/tags information alongside PDFs.
- Add month and tag filters, updated search, and richer Library UI interactions.
- Introduce share profiles (Standard/Compact) respecting user preferences and used by the export/download flows.
- Provide CSV export for filtered receipt lists.
- Persist new preferences in Settings and ensure tests cover the new data pathways.

## Milestone Breakdown

### 1. Metadata Model & Persistence
- Update `ReceiptIntelResult` & JSON schema to include editable tags/notes.
- Add `LibraryRepository.saveMetadataMap` to store arbitrary metadata maps; ensure `refresh()` reads and exposes them via `ScanEntry`.
- Ensure rename/delete logic continues to manage sidecar JSON files.
- Tests: extend `library_repository_test.dart` to verify save/load cycle and new fields.

### 2. Library Filters & UI
- Create `LibraryFilters` state model (month, tags, text query).
- Compute distinct months (Year-Month) and tag counts from `ScanEntry` metadata.
- Update `LibraryScreen` with a filter drawer/pill row for month selection and multi-select tag chips; combine filters with existing search.
- Add empty-state messaging when filters hide all entries.
- Tests: widget/golden or unit coverage for filter combinations.

### 3. Metadata Editing Experience
- Implement `EditMetadataSheet` (modal bottom sheet) accessible from Library cards and PDF view.
- Fields: title (filename), vendor, purchase date (DatePicker), total (validated currency), payment method, tags (comma-separated).
- On submit, persist via `LibraryRepository.saveMetadataMap`, update display, and refresh filters.
- Tests: widget test covering validation and submission.

### 4. Share Profiles & Settings
- Define `ShareProfile` enum in `share_service.dart` (Standard, Compact for now).
- Update `ShareService` helpers to accept profile and adjust metadata payload (e.g., omit JSON when Compact).
- Extend `Settings` and `SettingsScreen` with preferred profile selection; default to Standard.
- Update `ExportScreen` to respect preference and allow per-share override.
- Tests: `share_service_test.dart` verifying payload differences by profile.

### 5. CSV Export
- Create `CsvService` that transforms current (or filtered) `ScanEntry` list into CSV, including date, vendor, total, tags, filename, document type, confidence.
- Add “Export CSV” action in Library (toolbar menu) and optional Settings preference for default month scope.
- Implement share flow using `Share.shareXFiles` with the generated CSV.
- Provide feedback on completion/errors.
- Tests: unit test ensuring CSV output matches expectations.

### 6. Polish & Regression Guard
- Update documentation (`commands.md`, `SPEC.md` summary) to reflect new flows.
- Run `flutter analyze`, `flutter test`, and add new coverage for services/components.
- Manual QA checklist: metadata edit → filter by month/tag → CSV export -> share with profile.

## Dependencies & Considerations
- Storage layout: new metadata fields must stay backward compatible with existing JSON to avoid breaking older exports.
- UI states: ensure long lists of tags/months remain scrollable and accessible (Material 3 chips, semantic labels).
- Share flows: watch for platform differences (iOS/Android) when sharing CSV or metadata-less payloads.

## Incremental Delivery Strategy
1. Merge metadata model changes + tests (Milestone 1).
2. Layer in Library filters (Milestone 2) and ensure analyzer/tests pass.
3. Add metadata editor (Milestone 3) once persistence is stable.
4. Integrate share profiles & settings (Milestone 4).
5. Deliver CSV export (Milestone 5) and final polish (Milestone 6).

This sequence keeps each PR manageable while progressively unlocking iteration 1 functionality within the Flutter app.
