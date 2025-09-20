# Image-to-PDF iOS App — Product & Technical Specification

## 1) Overview
- Purpose: A private, on-device iOS app to scan images into high-quality, searchable PDFs and share them seamlessly. It stands out via Receipt Intelligence, Share Safe for IDs, and a Face ID–protected Vault.
- Audience: Consumers, focusing on receipts and IDs first.
- Platforms: iOS (native).
- Privacy: 100% on-device; no network required to function.
- Integrations (share targets): Gmail, Google Drive, WhatsApp, SMS, AirDrop (via iOS share sheet presets).
- Locale: US English, US date/currency formats.
- Monetization: Free (initial phase).

## 2) Differentiators
- Receipt Intelligence: Extract vendor, date, subtotal, tax, total, payment method; auto-name files; monthly CSV export.
- Return Guard: Detect return windows and offer calendar reminders with store, amount, and receipt link.
- Share Safe (IDs): Preset redactions for sensitive fields and configurable watermark (diagonal or footer) with optional expiry.
- Private Vault: Face ID–protected storage for IDs/sensitive docs; metadata scrub on export; optional file encryption.
- Clean Scan Coach: Real-time guidance (glare, skew, cutoff) and automatic deskew/denoise for professional results.

## 3) Core User Flows
### 3.1 Modes
- Receipt Mode
  - Auto-capture, edge detection, perspective correction.
  - OCR and extract vendor/date/amounts; propose tags (Groceries, Electronics, etc.).
  - Auto-name: `YYYY-MM-DD_Vendor_$Total.pdf`.
  - Create stacks (multi-page) and collections (by month/store); share or export CSV.
- ID Mode (US Driver’s License and Student ID prioritised)
  - Guided front/back capture with glare/edge checks.
  - Share Safe sheet: toggle field redactions; choose watermark style/text; optional expiry; preview.
  - Save to Vault by default (with per-document override).

### 3.2 Share Profiles (via `UIActivityViewController`)
- Standard: Full PDF with selectable text layer and minimal compression.
- Share Safe (default for IDs): Irreversible redactions + watermark + metadata scrub.
- Compact: Optimized for messaging; target 3–5 page receipts under 2–3 MB while maintaining OCR quality.

### 3.3 Quick Actions
- Receipts: Export month CSV; create Return Guard reminder; split business vs. personal.
- IDs: Share Safe; set temporary access (expiry watermark); quick re-capture if quality score is low.

## 4) Technical Architecture (On-Device)
### 4.1 Capture & Image Processing
- Capture: `VisionKit` (`VNDocumentCameraViewController`) with auto-capture and edge detection.
- Corrections: Perspective correction, deskew, denoise, contrast enhancement (Core Image).
- Quality Coach: Heuristics for glare, skew angle, cutoff; prompt re-shoot when below thresholds.

### 4.2 OCR & Extraction
- OCR: `Vision` (`VNRecognizeTextRequest`, `.accurate`, `en-US`); keep line/box geometry.
- Receipt Parsing:
  - Dates/Amounts: `NSDataDetector` + currency regex; associate nearest labels (Total/Subtotal/Tax).
  - Vendor: Header lines with larger fonts; fallback to user entry; maintain canonical vendor list for auto-complete.
  - Payment: Regex for card network keywords and last-4 patterns.
- ID Field Detection:
  - Keyword/label proximity: DL/DLN/Driver License/DOB/Exp/Address; casing and position hints.
  - Confidence scores; user-adjustable masks.

### 4.3 Redaction & Watermark Pipeline
- Redaction: Render each page into a new image context (`CoreGraphics`), draw solid rectangles over redaction masks, then write into a fresh PDF via `PDFKit`. This removes underlying text and makes redactions irreversible.
- Watermarks:
  - Styles: `diagonal` (large, rotated, low alpha) and `footer` (small text).
  - Content: configurable purpose text, optional expiry date (e.g., “Expires 05/31/2025”).
  - Implementation: Draw `NSAttributedString` overlays during PDF page render.

### 4.4 PDF Generation & Searchability
- PDF: `PDFKit` pages built from processed images; add selectable text layer positioned using OCR boxes.
- Accessibility: Set correct reading order; add simple outlines/bookmarks per page; store extracted metadata in document info.
- Local Search: Core Spotlight or SQLite FTS for vendor, totals, dates, tags; entirely on-device.

### 4.5 Security & Vault
- Storage: App container with `NSFileProtectionComplete` for at-rest protection.
- Vault: Enabled by default for IDs; Face ID (`LocalAuthentication`) required to view/export; auto-lock on background.
- Optional Encryption: File-level AES-GCM using `CryptoKit`; random 256-bit key in Keychain; per-file nonce.
- Metadata Hygiene: Remove location/capture metadata and thumbnails on Share Safe export.

### 4.6 Compression Strategy (Target < 2–3 MB for 3–5 pages)
- Receipts: Binarize (threshold/CLAHE), 150–200 DPI, JPEG with adaptive quality or CCITT Group 4 for true B/W pages.
- IDs: Keep color; downscale to ~220–300 DPI; JPEG quality ~0.6–0.75; cap max dimensions.
- Budgeting: Allocate target size per page and adjust quality iteratively; ensure OCR layer alignment post-resample.

### 4.7 Reminders & Calendar
- Return Guard: Detect “return by/within” phrases or default 30 days; create calendar events with `EventKit` including vendor, amount, and link to file.

### 4.8 Sharing
- `UIActivityViewController` with presets for Gmail, Google Drive, WhatsApp, SMS, AirDrop.
- Share profiles preselect target-friendly formats (Standard/Share Safe/Compact) and filenames.

## 5) Data Model (Lightweight)
- Receipt
  - id (UUID), created_at, updated_at
  - vendor, date, subtotal, tax, total
  - payment_method, payment_last4
  - tags[]
  - pages[] (images or references)
  - ocr_blocks[] (text + boxes)
- IDDocument
  - id (UUID), type (DL | StudentID)
  - front_page, back_page
  - redaction_masks[] (page, rect, label, confidence)
  - watermark { style (diagonal|footer), text, expiry_date? }
  - vault_only (bool)
- VaultSettings
  - enabled (bool), auto_for_ids (bool), require_faceid_for_export (bool)

## 6) CSV Export
- Columns: Date, Vendor, Category, Subtotal, Tax, Total, PaymentMethod, Last4, Notes, FileName.
- Filters: Month range and/or tag; export to Files or share.

## 7) Acceptance Criteria (Key Features)
- Redactions: Searching/copying text in exported Share Safe PDFs reveals no redacted content.
- Watermark: User can choose diagonal/footer and set custom text; optional expiry renders correctly.
- Vault: IDs default to Vault; viewing/exporting requires Face ID; app backgrounding re-locks Vault.
- Compression: Default Compact keeps 3–5 page receipts under 2–3 MB 80%+ of the time with legible OCR.
- Offline: All core features run with no network access.
- OCR Quality: On the sample set, total/date detection ≥90% accuracy; vendor extraction ≥80% with manual correction flow.

## 8) Metrics (On-Device, Privacy-Preserving)
- Capture success rate (no re-shoots needed).
- OCR extraction accuracy (totals/date/vendor).
- Share Safe usage rate for IDs.
- CSV export runs per active month.
- Return reminders created vs. clicked.
- Median export size for receipts (pages, MB).

## 9) Roadmap
- MVP (Weeks 1–3)
  - Scan → PDF with OCR and auto-crop/deskew.
  - Receipt extraction (vendor/date/total), auto-naming, tagging.
  - Share sheet (Standard/Compact) and CSV export (basic).
- v1 (Weeks 4–6)
  - Return Guard reminders.
  - Share Safe for IDs with redaction presets and watermark options.
  - Private Vault with Face ID and metadata scrub.
  - Local search index (vendor/date/amount/tags).
- v1.1 (Weeks 7–8)
  - Collections/Stacks and batch export.
  - Quality score coach + auto-fixes.
  - Duplicate detection via perceptual hash.

## 10) Defaults & Decisions (Confirmed)
- ID scope: Prioritize US Driver’s License and Student ID.
- Watermark: Support diagonal and footer; user-configurable purpose text; optional expiry.
- Vault: Default ON for IDs with per-document override after first use; Face ID required for view/export.
- File size: Optimize Compact profile to keep 3–5 page receipts under 2–3 MB.
- Return window: Default 30 days when not detected.

## 11) Non-Goals (Current Phase)
- Cloud services, accounts, or cross-device sync.
- Non-US locales or multi-language OCR.
- Desktop/web apps.
- Budgeting/finance features beyond CSV export and simple tags.

## 12) Risks & Mitigations
- OCR variability on poor scans → Quality coach, auto-fixes, and easy manual corrections.
- False redaction detection on IDs → Presets + user-adjustable masks with preview.
- File size vs. legibility tradeoff → Adaptive per-page quality budgeting and user-selectable profiles.
- Privacy regressions → No network calls in core flows; periodic self-checks for accidental telemetry.

## 13) Testing Strategy
- Unit tests: extraction heuristics (dates, totals, vendor), redaction rendering, watermark placement math.
- Integration tests: end-to-end scan→OCR→PDF→share on sample images.
- Regression samples: curated receipt and ID images in `samples/`.
- Acceptance test playbooks matching criteria in section 7.

---
This specification captures the approved scope for an iOS, on-device Image-to-PDF/OCR app focused on receipts and IDs, with standout features (Receipt Intelligence, Share Safe, Vault) and a lean roadmap to MVP → v1.
