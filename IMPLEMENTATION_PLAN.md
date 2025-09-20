# End-to-End Implementation Plan (iOS, On-Device)

This plan turns SPEC.md into a shippable, on-device iOS app via clear, iterative milestones. Each iteration delivers a complete, testable vertical slice. No cloud dependencies.

References: see SPEC.md for product scope and acceptance criteria.

## Architecture & Modules
- App shell
  - Pattern: MVVM + Coordinators; Swift, iOS 16+.
  - Modules: Capture, Processing, OCR, Extraction, PDF, Redaction, Watermark, Vault, Search, Share, CSV, Reminders.
- Key services (targets/Swift packages)
  - CaptureKit: VisionKit wrappers, camera coordinator, quality coach.
  - ImageFX: Core Image pipeline (deskew, denoise, contrast, binarize), DPI/downscale utilities.
  - OCRKit: Vision text recognition, block/line geometry, language `en-US`.
  - ReceiptIntel: parsing heuristics (dates, totals, vendor, payment), tagging, auto-naming.
  - PDFBuilder: PDFKit wrapper, text layer placement, outlines, metadata.
  - Redactor: irreversible mask renderer (CoreGraphics) + PDF rebuild; export profiles.
  - Watermarker: diagonal/footer text overlays with style presets.
  - Vault: file protection (NSFileProtectionComplete), CryptoKit AES-GCM optional encryption, Face ID gating.
  - SearchIndex: Core Spotlight integration; local index of vendor/date/total/tags.
  - ShareHub: `UIActivityViewController` presets, filename strategies, profile bindings.
  - CSVExporter: CSV schema + range/tag filters.
  - ReminderSvc: EventKit integration for Return Guard.
  - Store: Core Data (or file-based JSON) + file system layout; Keychain for keys.

## Data Model (Core Data Sketch)
- ReceiptEntity: id, createdAt, updatedAt, vendor, date, subtotal, tax, total, paymentMethod, last4, tags, fileURL, ocrIndex
- IDDocumentEntity: id, type, frontURL, backURL, vaultOnly, watermarkStyle, watermarkText, expiryDate, redactionMasksJSON
- SettingsEntity: vaultEnabled, autoForIDs, requireFaceIDForExport

## Iterative Roadmap (Vertical Slices)

### Iteration 0 — Foundations (1 week)
Goal: Project scaffolding, base capture, simple PDF export; establish testing and storage.
- Deliverables
  - Xcode project, targets, SwiftPM setup; app skeleton with tabs: Scan, Library, Settings.
  - Capture flow via VisionKit; manual crop/rotate; save images to sandbox.
  - Minimal PDF export (no OCR), Standard share profile; file naming manual.
  - Core Data store (or JSON store) + file layout; Settings screen with Vault toggles (no enforcement yet).
  - Basic unit/UI test harness (XCTest + sample images in app bundle for dev).
- Acceptance
  - User scans 1–3 pages and shares a PDF via share sheet.
  - Files persist across app restarts; appear in Library with thumbnails.

### Iteration 1 — Receipt MVP (1–2 weeks)
Goal: Searchable PDFs, receipt extraction, auto-naming, Compact export.
- Deliverables
  - OCRKit: Vision recognition with word/line boxes; text layer added in PDFBuilder.
  - ReceiptIntel: extract date/total/vendor; auto-name `YYYY-MM-DD_Vendor_$Total.pdf`.
  - ImageFX: deskew/denoise/contrast; Compact export profile with target 3–5 pages < 2–3 MB.
  - Library: filters by month, tags; edit vendor/date/total; re-export.
  - CSVExporter: basic monthly CSV from Receipts.
  - ShareHub: Standard and Compact profiles.
- Acceptance
  - 5-page receipt exports under 2–3 MB median with selectable text.
  - Auto-name populated from extraction; user can edit.
  - CSV export for current month shares via sheet.

### Iteration 2 — ID Mode + Share Safe + Vault (2 weeks)
Goal: Private ID flow with irreversible redaction, watermarks, and Face ID vault.
- Deliverables
  - ID capture: guided front/back, glare/edge checks; combined preview.
  - Redactor: field mask presets (DLN, DOB, Address, Exp); user toggles and adjusts boxes.
  - Watermarker: diagonal or footer style; custom text; optional expiry.
  - Vault: default ON for IDs; Face ID gate to view/export; NSFileProtectionComplete; optional AES-GCM encryption.
  - ShareHub: Share Safe profile (redact + watermark + metadata scrub) as default for IDs.
- Acceptance
  - Redacted PDFs reveal no underlying text via copy/search.
  - Watermark renders per user choice; expiry shows correctly.
  - Opening/exporting a Vaulted ID requires Face ID; app locks on background.

### Iteration 3 — Return Guard, Search, Collections (1–1.5 weeks)
Goal: Turn extraction into action and improve organization and discovery.
- Deliverables
  - Return Guard: detect return windows or default 30 days; EventKit event with vendor/amount/link.
  - SearchIndex: Core Spotlight entries for receipts (vendor/date/total/tags).
  - Collections/Stacks: auto-group by month/store; batch export.
  - Duplicate detection: perceptual hash to flag/merge duplicates.
- Acceptance
  - Creating a reminder from a receipt places a dated calendar entry.
  - iOS system search surfaces stored receipts by vendor or total.
  - Users can export a stack as one PDF.

### Iteration 4 — Quality, Accessibility, Polish (1 week)
Goal: Stabilize, meet accessibility, refine performance, and finalize release.
- Deliverables
  - Quality coach: glare/skew/cutoff prompts; retry guidance.
  - Accessibility: VoiceOver labels, proper reading order; large text support.
  - Performance: preflight size budgeting; progressive JPEG; IO tuning.
  - Settings: export defaults; diagnostics screen (no PII) for support.
  - Final QA pass, regression suite, release notes.
- Acceptance
  - Capture guidance reduces retakes in test runs.
  - 80% of multi-page receipts meet size targets with legible OCR.
  - All UI paths accessible with VoiceOver.

## End-to-End Flow (Target State)
1) Capture (Receipt) → ImageFX auto-fix → OCRKit text → ReceiptIntel extract → PDFBuilder (text layer) → ShareHub (Standard/Compact) → Library indexed → CSV/Reminders.
2) Capture (ID) → Masks (Redactor) + Watermarker → PDFBuilder (rasterized for redaction) → Vault storage → ShareHub (Share Safe) with Face ID gate.

## Detailed Task Breakdown (by module)
- CaptureKit
  - Implement coordinator with VisionKit VC; multi-page capture; manual crop.
  - Quality metrics: skew angle, glare heuristic, edge coverage; UI prompts.
- ImageFX
  - Deskew (CIPerspectiveTransform), denoise (CINoiseReduction), contrast; binarize; DPI control.
  - Adaptive downscale + JPEG quality selection; CCITT Group 4 for B/W.
- OCRKit
  - VNRecognizeTextRequest pipeline; text blocks with geometry; error handling and retries.
- ReceiptIntel
  - Date/amount via NSDataDetector + regex; vendor header heuristics; payment last4; tags; confidence scores.
  - Auto-naming and filename conflict resolution.
- PDFBuilder
  - Page builder; text layer placement via OCR geometry; outlines/bookmarks; doc metadata.
- Redactor
  - Mask model (page, rect, label, confidence); interactive editor overlay.
  - Irreversible rasterization render → PDF; metadata scrub.
- Watermarker
  - Diagonal/footer presets; attributed text; rotation, opacity, layout across aspect ratios.
- Vault
  - File container path with NSFileProtectionComplete; CryptoKit AES-GCM wrapper.
  - LocalAuthentication gate; background lock notifications; export re-auth.
- SearchIndex
  - Core Spotlight items; string tokens vendor/date/total/tags; reindex on edit.
- ShareHub
  - Profiles: Standard/Compact/Share Safe; activity items and default filenames per profile.
- CSVExporter
  - Schema, filters (month, tag); file write and share; error fallbacks.
- ReminderSvc
  - Phrase detection; EventKit permission flow; event creation with deep link/open-in-app.
- Store
  - Core Data model, migrations; lightweight JSON export for debug.

## Testing Strategy
- Unit tests (XCTest)
  - Extraction: totals/date/vendor heuristics, masks serialization, watermark layout math.
  - PDFBuilder: text layer alignment tests; redaction rasterization integrity (no text under masks).
  - ImageFX: deskew/binarize outputs within thresholds on samples.
- Integration tests
  - Receipt E2E: sample images → PDF with correct filename and size budget.
  - ID E2E: front/back → Share Safe export; search confirms redactions removed.
- Manual acceptance
  - Playbooks matching SPEC section 7 criteria; device tests on recent iPhones.

## Definition of Done (per iteration)
- Code compiles without warnings; unit tests pass (>=80% for touched modules).
- Accessibility basic checks complete; no blocking crashes; size/perf targets met for scope.
- Update SPEC.md status and CHANGELOG with shipped items; capture screenshots for QA log.

## Repo Layout (iOS project)
- ios/
  - App/ (UI, Coordinators, ViewModels)
  - Core/ (CaptureKit, ImageFX, OCRKit, ReceiptIntel, PDFBuilder, Redactor, Watermarker, Vault, SearchIndex, ShareHub, CSVExporter, ReminderSvc, Store)
  - Resources/ (Assets.xcassets, Localizable.strings, Samples for dev)
  - Tests/ (Unit and UI tests)
- SPEC.md (already present)
- IMPLEMENTATION_PLAN.md (this file)

## Timeline & Resourcing (suggested)
- Iteration 0: 1 week
- Iteration 1: 1–2 weeks
- Iteration 2: 2 weeks
- Iteration 3: 1–1.5 weeks
- Iteration 4: 1 week
Single iOS engineer can deliver with focused scope; add QA in Iteration 4.

## Risks & Mitigations
- OCR accuracy on low-quality scans → Quality coach + manual corrections + robust fallbacks.
- Redaction mistakes → User-adjustable masks, preview, irreversible rasterization.
- File size vs readability → Adaptive per-page budgeting, user-selectable profiles.
- Privacy regressions → No third-party SDKs; verify no network calls in core paths.

## Next Steps
- Confirm Core Data vs JSON store choice (default: Core Data).
- Create ios/ project scaffold (targets + SwiftPM); stub modules and sample screens.
- Start Iteration 0 tasks and track progress in issues/sprint board.
