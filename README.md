# Image to PDF Scanner

Cross-platform mobile app for capturing receipts/documents, exporting polished PDFs, and managing a metadata-rich library. The repo hosts:

- `mobile_app/` – Flutter codebase targeting iOS & Android.
- `ios/` – Native Swift modules (VisionKit capture, ImageFX, OCRKit, PDFBuilder, etc.) plus a demo SwiftUI shell for future native iterations.

## Highlights

- Capture pages with the device camera (VisionKit on device / Camera plugin fallback on Simulator), import from Photos/Files, or add sample pages for testing.
- OCR + Receipt Intelligence heuristics auto-suggest vendor, purchase date, totals, card hints, and filenames; metadata is persisted in sidecar JSON files.
- Export configurable PDFs (Color/Gray/B&W, quality 60–95), preview instantly, and share via Standard or Compact share profiles.
- Library view lists all stored PDFs with month & tag filters, search, tag chips, and quick actions (edit metadata, rename, share, delete).
- Metadata editor sheet lets you adjust vendor/date/total/tags/notes/document type inline—changes sync back to the library and sidecar JSON.
- Settings screen persists default color mode, JPEG quality, and share profile across sessions.

## Repository Layout

```
.
├── mobile_app/                # Flutter application
│   ├── lib/
│   │   ├── screens/           # UI (library, capture, review, export, settings, metadata editor)
│   │   └── services/          # PDF, share, library, OCR, settings helpers
│   └── test/                  # Flutter/Dart tests
├── ios/                       # Native Swift modules + demo app scaffolding
├── README.md                  # (this file)
├── SPEC.md                    # Product requirements
├── IMPLEMENTATION_PLAN.md     # Iteration plan
├── commands.md                # Handy one-liners
└── LAUNCHING_FLUTTER_APP.md   # Detailed Flutter run guide
```

## Prerequisites

- Flutter SDK (`flutter doctor` clean)
- Xcode 16+, Apple Developer mode enabled for device testing
- CocoaPods (`sudo gem install cocoapods`)
- Optional Android SDK for running on Android devices/emulators
- For native Swift modules: Xcode 16.x, Swift 5.9+

Quick verification:

```
flutter --version
xcodebuild -version
```

## Getting Started – Flutter

Run from repo root unless noted.

```bash
make setup                    # Fetch Flutter deps, run pod install
make run-ios-sim SIMULATOR_NAME="iPhone 15"
# or
make run-android
```

Hot reload: press `r` / `R` in the Flutter console. If CocoaPods complains, open `mobile_app/ios` in Xcode once then run `make pods`.

For more detail (device provisioning, screenshots), see `LAUNCHING_FLUTTER_APP.md`.

## iOS Native Demo (Swift)

Follow `ios/XCODE_SETUP.md` to create/open an Xcode project, add `ios/Core` + `ios/App`, link Vision/PDFKit/PhotosUI, set signing, and run. The Swift modules mirror the roadmap in `SPEC.md` and `IMPLEMENTATION_PLAN.md` (CaptureKit, ImageFX, OCRKit, ReceiptIntel, PDFBuilder, CSVExporter, ShareHub, etc.).

## Running & Testing

Top-level wrappers:

- `make setup`, `make run-ios[-sim]`, `make run-android`
- `make pods`, `make clean`, `make analyze`
- `make test` → `flutter test`

Direct commands:

```bash
flutter devices
flutter run
flutter test
flutter analyze
```

## App Walkthrough (Flutter)

### Library

- Displays PDFs stored under `Documents/scans/` with receipt metadata.
- Filters: free-text search + month chips + tag chips (multi-select). Clear filters or search via quick actions.
- Cards show filename, document type, vendor/date/total summary, tag chips, and actions:
  - **Edit metadata** → opens the metadata sheet (vendor/date/total/payment/tags/notes/doc type)
  - Rename, Share, Delete
- Share actions respect the default share profile saved in Settings (Standard = includes metadata JSON, Compact = PDF only).

### Capture & Review

- Live camera preview (permission-aware). Simulator offers “Add sample page” for testing.
- Import from Photos or Files; imported PDFs are copied into the library.
- Review screen lets you reorder/remove pages before export.

### Export

- Runs OCR + Receipt Intel, suggests filenames, and surfaces a summary card.
- Configure color mode and quality sliders.
- Share sheet now includes a profile selector (Standard/Compact) mirroring the Settings default; metadata editor notes flow into the generated summary.
- Last exported path surfaced for quick access.

### Settings

- Persist default color mode, JPEG quality, and share profile (Standard/Compact).
- Save/Reset buttons update `settings.json` (Documents directory) consumed by Export/Share flows.

## Metadata & Storage

- PDFs saved to `Documents/scans/`.
- Receipt metadata stored beside each PDF as `<filename>.receipt.json` (vendor/date/total/tags/notes/etc.).
- Tags normalized (case-insensitive, trimmed) for filtering; deleting metadata removes the sidecar file.

## Sharing Behavior

| Profile   | Metadata JSON | Subject suffix     |
|-----------|---------------|--------------------|
| Standard  | Included      | Unchanged          |
| Compact   | Omitted       | Adds “(Compact)”   |

Profiles are selectable in Settings, exported share sheet, and library/PDF share actions.

## Native Modules Status (`ios/`)

Available: ImageFX stubs, OCRKit, PDFBuilder, ReceiptIntel, CSVExporter, ShareHub. Planned modules (Redactor, Watermarker, Vault, SearchIndex, ReminderSvc) follow the timelines in `IMPLEMENTATION_PLAN.md`. Use Xcode project setup to experiment with the SwiftUI demo.

## Troubleshooting

- **No devices/simulators**: `flutter devices`; `xcrun simctl boot "iPhone 15"`.
- **Persistent Pod/Xcode errors**: `make clean && make pods && make run-ios-sim`.
- **Camera unavailable (Simulator)**: use Import or Add Sample.
- **Share targets missing (simulator)**: fallback “Share…” option uses system sheet.
- **Xcode signing**: ensure Developer Mode enabled and bundle identifier matches your team.

## Development Notes

- Linting: `flutter analyze`
- Tests: `flutter test` (widget + service coverage). New tests include metadata normalization and share-profile payload validation.
- Conventional commits preferred (`feat:`, `fix:`, `docs:`, etc.). Keep docs/tests synchronized with behavior changes.
- Avoid committing large binaries or secrets. Use `.env` / `--dart-define` for configuration.

## Roadmap (See `SPEC.md`, `IMPLEMENTATION_PLAN.md`)

- Native VisionKit capture & preprocessing pipeline integration via platform channels.
- CSV export surface in Flutter (uses stored metadata).
- Native redaction/watermark/vault flows for ID mode.
- Advanced search (Core Spotlight) & reminder automation.

## License

No license specified. Add one before publishing or sharing externally.

