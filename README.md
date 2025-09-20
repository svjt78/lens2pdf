Image to PDF Scanner

An image-to-PDF mobile app. Capture or import images, adjust export settings (color/gray/B&W, quality), generate a PDF, and manage your scans in a structured library view enriched with receipt metadata. This repository contains:

- A Flutter app under `mobile_app/` (iOS/Android)
- Native iOS core modules and demo scaffolding under `ios/` (Swift, iOS 16+)

- Platforms: iOS (Simulator + device), Android (device/emulator)
- Status: MVP — Flutter app implements end-to-end scanning and sharing; native iOS modules are scaffolded for future iterations.

Features

- Capture with device camera or import from Photos/Files (Simulator: use Add sample)
- On-device OCR + receipt intelligence → auto-fills vendor/date/total, card info, confidence, and suggests a descriptive filename
- Export to PDF with adjustable quality and color mode and view/share immediately
- Library persists scans (rename/delete/share) and now shows receipt details above the PDF when you open it
- Metadata is cached beside each PDF so summary data survives app restarts without re-running OCR
- Idempotent platform permission helpers for Android/iOS

Repository Layout

- `mobile_app/` — Flutter app (Dart + platform shells)
- `ios/` — Native iOS Swift modules and demo app scaffolding
  - `ios/README.md` — Overview of modules (OCRKit, ReceiptIntel, ImageFX, PDFBuilder, CSVExporter, ShareHub)
  - `ios/App/README.md` — Demo app usage and file map (SwiftUI)
- `Makefile` — Root wrappers that call `mobile_app/Makefile`
- `LAUNCHING_FLUTTER_APP.md` — Step‑by‑step Flutter launch guide (simulator + device)
- `ios/XCODE_SETUP.md` — How to run the native iOS demo (Swift)
- `SPEC.md` / `IMPLEMENTATION_PLAN.md` — Product spec and implementation roadmap
- `commands.md` — Quick command cheat‑sheet

Prerequisites

- Flutter SDK installed and `flutter doctor` clean
- Xcode + Command Line Tools (enable Developer Mode on physical devices)
- CocoaPods for iOS: `sudo gem install cocoapods`
- iOS deployment target **15.5+** (required by Google ML Kit)
- Android toolchain/SDK (optional)
- For native iOS demo (optional): Xcode 16.x, Swift 5.9+

Verify tools:

```
flutter --version
xcodebuild -version
```

Quick Start (iOS Simulator, Flutter)

See also `LAUNCHING_FLUTTER_APP.md` for a detailed walkthrough.

```
# From repo root
make setup && make -C mobile_app ios-permissions
make boot-sim SIMULATOR_NAME="iPhone 15"   # optional; defaults to iPhone 15
make run-ios-sim SIMULATOR_NAME="iPhone 15"
```

- Hot reload: press `r` (reload) or `R` (restart) in the Flutter console
- If `pod install` fails, open `mobile_app/ios` in Xcode once, then run `make pods`

Quick Start (Android)

```
# From repo root
make setup
make run-android
```

Ensure an emulator/device is available: `flutter devices`.

Native iOS (Swift) Quick Start

For the iOS Swift modules and demo UI, follow `ios/XCODE_SETUP.md`. In short:

- Create a new SwiftUI app in Xcode (or open your existing project).
- Add the local Swift package from `ios/` (or drag `ios/Core` and `ios/App` into the project).
- Link Apple frameworks: Vision, PDFKit, PhotosUI.
- Set signing, select a simulator/device, and run.
- See also: `ios/App/README.md` for the demo app and file map.

**iOS Modules Features**

- Available now (under `ios/Core`)
  - OCRKit: Vision-based OCR (`VNRecognizeTextRequest`), line/box geometry, `en-US`.
  - PDFBuilder: PDFKit pages, optional selectable text layer, basic metadata.
  - ImageFX: Minimal processing (downscale/JPEG re-encode placeholder); DPI helpers.
  - ReceiptIntel: Heuristics for vendor/date/subtotal/tax/total; auto-naming.
  - CSVExporter: Monthly CSV export function.
  - ShareHub: Share profiles scaffolding (Standard, Compact) with filename strategies.

- Planned/scaffolded (see `SPEC.md`, `IMPLEMENTATION_PLAN.md`)
  - Redactor: Irreversible redaction pipeline (rasterize + rebuild PDF).
  - Watermarker: Diagonal/footer watermarks with customizable text/expiry.
  - Vault: Face ID–protected storage, NSFileProtectionComplete; optional AES-GCM.
  - SearchIndex: Core Spotlight entries for local search.
  - ReminderSvc: Return Guard calendar reminders via EventKit.

Make Targets (root wrappers)

- `make setup` — Scaffold platforms and fetch deps
- `make run-ios-sim` — Run on named iOS Simulator (`SIMULATOR_NAME="iPhone 15"`)
- `make boot-sim` — Boot/open the iOS Simulator by name
- `make run-ios` — Run on an iOS device/simulator (Flutter decides)
- `make run-android` — Run on Android device/emulator
- `make pods` — Install CocoaPods under `mobile_app/ios`
- `make test` — Run Flutter tests
- `make analyze` — Run analyzer/lints
- `make clean` — Clean Flutter build artifacts
- `make doctor` — Print `flutter doctor` and devices

All targets accept extra Flutter flags via `ARGS="--release --dart-define=KEY=VAL"`.

Command Cheat‑Sheet

- Common one‑liners: see `commands.md`.

App Walkthrough

- **Library**
  - Lists PDFs stored under `Documents/scans/` displaying filename and creation timestamp
  - Supports rename/share/delete; tapping opens the PDF preview with receipt summary (vendor, purchase date, totals, payment info, confidence)
- **Capture**
  - Live camera preview (falls back to sample/import on Simulator)
  - Batch import from Photos/Files; PDFs copied into the library automatically
- **Review**
  - Reorder/remove pages before exporting
- **Export**
  - Adjust color mode (Color/Grayscale/B&W) and quality (60–95)
  - Runs OCR + receipt intel to propose filename and metadata
  - Exported PDFs saved to `Documents/scans/<auto_name>.pdf` with `.receipt.json` sidecar metadata
  - Share directly or open the PDF preview with summary card

Where files are stored

- iOS/Android: App documents directory at `Documents/scans/`
- Imported PDFs from Files are copied into the same directory
- Receipt metadata lives beside each PDF as `<filename>.receipt.json`

Permissions

- iOS: Info.plist keys are inserted by `make -C mobile_app ios-permissions`
  - `NSCameraUsageDescription`
  - `NSPhotoLibraryUsageDescription`
- Android: `make -C mobile_app android-permissions` adds camera/gallery permissions to the manifest (idempotent)

Simulator Notes (iOS)

- Camera is unavailable; use Import or “Add sample”
- Email/SMS/WhatsApp/Airdrop are not installed; buttons fall back to the generic share sheet
- Use the “Share…” option to exercise attachment flow (e.g., Save to Files)

Native Integrations

- Flutter method channels:
  - `share_targets` for Airdrop, Email, SMS, WhatsApp shortcuts (with graceful fallbacks)
  - `cv` (placeholder) for native preprocessing hooks
- Native iOS (Swift) modules under `ios/` still house the long-term Receipts/ID feature set (OCRKit, ReceiptIntel, PDFBuilder, etc.). Integration work is tracked in `SPEC.md` / `IMPLEMENTATION_PLAN.md`.

Troubleshooting

- No devices shown: `flutter devices`; open Simulator; `xcrun simctl boot "iPhone 15"`
- Stuck or odd build: `make clean && make pods && make run-ios-sim`
- Reset unavailable simulators: `xcrun simctl delete unavailable`
- Change active Xcode path: `sudo xcode-select --switch /Applications/Xcode.app`

Development

- Code style: Flutter/Dart defaults for `mobile_app/` (`make analyze`); Swift style for `ios/` per Xcode defaults
- Tests: `make test` (Flutter), XCTest targets inside `ios/` if added
- Docs: detailed Flutter run guide in `LAUNCHING_FLUTTER_APP.md`; native iOS setup in `ios/XCODE_SETUP.md`

Contributing

- Use Conventional Commits (`feat:`, `fix:`, `docs:`, `refactor:`, `test:`, `chore:`).
- Keep changes focused; update docs/tests as needed.
- Avoid committing large binaries or secrets.

Security

- No hard‑coded secrets are present. Do not commit secrets or large artifacts.
- For future API keys, prefer `--dart-define` and platform‑specific secure storage.

Roadmap / Ideas

- Native OpenCV preprocessing for grayscale/B&W (iOS/Android)
- Thumbnails in Library and review
- OCR pipeline and searchable PDFs
  - Native iOS modules in `ios/` track this; see `SPEC.md` and `IMPLEMENTATION_PLAN.md`

License

- Add your license of choice. By default, no license is set.
