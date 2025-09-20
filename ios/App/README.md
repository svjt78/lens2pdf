# iOS Demo App (SwiftUI) — Iteration 1

This SwiftUI app scaffolds a minimal demo for Iteration 1 (Receipt MVP):
- Select photos (receipts) via PhotosPicker
- Process images (Compact), OCR them, extract vendor/date/total
- Build a PDF with a text layer
- Share via the iOS share sheet with a suggested filename

Paths:
- App entry: `ios/App/App.swift`
- ViewModel pipeline: `ios/App/ViewModels/ScanViewModel.swift`
- UI: `ios/App/Views/ContentView.swift`
- Share sheet wrapper: `ios/App/Views/ActivityView.swift`
- Core modules: under `ios/Core/*`

How to run in Xcode (16.4):
See `ios/XCODE_SETUP.md` for a detailed guide with two options:
- Option A: Create an iOS app and drag in `ios/Core` + `ios/App` sources.
- Option B: Add the local Swift Package (`ios/Package.swift`) as `ImageToPDFCore` for core logic, then add `ios/App` for UI.

Quick steps (Option A):
1) Create a new iOS App (SwiftUI, iOS 16+).
2) Drag `ios/Core` and `ios/App` into the project (Create groups).
3) Link frameworks: Vision, PDFKit, PhotosUI.
4) Ensure `ImageToPDFApp` is the app entry.
5) Run and test with PhotosPicker.

Notes:
- PhotosPicker does not require photo library permission; it presents a picker UI.
- Vision/PDFKit features activate only on iOS; the code uses conditional compilation to remain portable.
- Image processing is minimal here; expand `ImageFX` as per SPEC.md for best results.
