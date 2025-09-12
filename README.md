Image to PDF Scanner (Flutter)

A lightweight image-to-PDF mobile app built with Flutter. Capture or import images, adjust export settings (color/gray/B&W, quality), generate a PDF, and manage your scans in a simple library view. This repository hosts the Flutter app under `mobile_app/` and convenience wrappers at the repo root.

- Platforms: iOS (Simulator + device), Android (device/emulator)
- Status: MVP — sharing targets and OpenCV hooks are implemented via method channels; native sides are minimal/best‑effort.

Features

- Capture with camera or import from Photos/Files (Simulator: use Add sample)
- Export to PDF with adjustable quality and color mode
- Share via platform share sheet; shortcuts for Airdrop, Email, SMS, WhatsApp
- Library with rename, delete, share, and PDF viewer
- Idempotent platform permission helpers for Android/iOS

Repository Layout

- `mobile_app/` — Flutter app (all Dart/Swift/Android sources)
- `Makefile` — Root thin wrappers that call `mobile_app/Makefile`
- `SIMULATOR_DEPLOY.md` — One‑liners to run on an iOS Simulator
- `LAUNCHING_FLUTTER_APP.md` — Step‑by‑step launch guide (iOS + device)

Prerequisites

- Flutter SDK installed and `flutter doctor` clean
- Xcode + Command Line Tools for iOS (open Xcode once)
- CocoaPods for iOS: `sudo gem install cocoapods`
- Android toolchain/SDK for Android (optional)

Verify tools:

```
flutter --version
xcodebuild -version
```

Quick Start (iOS Simulator)

See also `SIMULATOR_DEPLOY.md` for copy‑paste one‑liners.

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

App Walkthrough

- Home (Library)
  - Displays PDFs saved under app documents at `Documents/scans/`
  - Long‑lived view; it auto‑refreshes when returning from capture/export
  - Supports rename, share, delete; tapping opens the in‑app PDF viewer
- Capture
  - Shows camera preview when available; on Simulator, camera is unavailable
  - Use Import to pick images or PDFs from Files/Photos; “Add sample” creates a placeholder page
- Review
  - Reorder and remove pages before export
- Export
  - Color mode: Color, Grayscale, B&W
  - Quality slider (60–95)
  - Exports to `Documents/scans/Scan_YYYYMMDD_HHMM_{n}p.pdf`
  - Share sheet with shortcuts (Airdrop/Email/SMS/WhatsApp) and a generic “Share…” option

Where files are stored

- iOS/Android: App documents directory at `Documents/scans/` (created on demand)
- Imported PDFs from Files are copied into `Documents/scans/` so they appear in Library immediately

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

- Method channels:
  - `share_targets` (iOS: AppDelegate.swift) for Airdrop, Email, SMS, WhatsApp shortcuts; gracefully falls back to generic sharing
  - `cv` (optional) for image pre‑processing; currently no‑op unless native side is implemented

Troubleshooting

- No devices shown: `flutter devices`; open Simulator; `xcrun simctl boot "iPhone 15"`
- Stuck or odd build: `make clean && make pods && make run-ios-sim`
- Reset unavailable simulators: `xcrun simctl delete unavailable`
- Change active Xcode path: `sudo xcode-select --switch /Applications/Xcode.app`

Development

- Code style: Flutter/Dart defaults; run `make analyze`
- Tests: `make test`
- Docs: detailed run guides in `SIMULATOR_DEPLOY.md` and `LAUNCHING_FLUTTER_APP.md`

Security

- No hard‑coded secrets are present. Do not commit secrets or large artifacts.
- For future API keys, prefer `--dart-define` and platform‑specific secure storage.

Roadmap / Ideas

- Native OpenCV preprocessing for grayscale/B&W (iOS/Android)
- Thumbnails in Library and review
- OCR pipeline and searchable PDFs

License

- Add your license of choice. By default, no license is set.
