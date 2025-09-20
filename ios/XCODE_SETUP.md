# Xcode 16.4 Setup (iOS Demo)

This repo already includes Swift sources for a minimal iOS demo app (SwiftUI) and core modules. Follow one of the setups below.

Option A (recommended): New Xcode app + drag sources
1) Create project
   - Open Xcode 16.4 → File → New → Project… → iOS → App.
   - Product Name: ImageToPDF (any name is fine)
   - Interface: SwiftUI, Language: Swift, Minimum iOS: 16.0
   - Choose a folder to save the project (outside this repo or inside `ios/App/` if you prefer).

2) Add sources
   - In Finder, locate this repo’s `ios/Core` and `ios/App` folders.
   - In Xcode’s Project Navigator, right‑click your app target group → “Add Files to …”.
   - Select both `ios/Core` and `ios/App` folders.
   - In the dialog: “Create groups”, check “Copy items if needed” if you want local copies in the project; otherwise leave unchecked to reference files in place.
   - Ensure your app target is checked under “Add to targets”.

3) Link Apple frameworks
   - Select your app target → General → Frameworks, Libraries, and Embedded Content → “+”.
   - Add: Vision, PDFKit, PhotosUI.

4) Set app entry
   - Ensure `App.swift` has `@main struct ImageToPDFApp: App { … }`.
   - If you used a different product name, either rename the struct or set the target’s main app file accordingly (default is automatic for SwiftUI apps).

5) Signing and run
   - Targets → Signing & Capabilities → set a Team, and ensure a valid Bundle Identifier.
   - Select a simulator or device and press Run. Use PhotosPicker to pick images → tap “Process → PDF”.

Option B: Use the Swift Package for Core
This keeps the app code and the core logic modular.

1) Create project
   - Same as Option A, step 1.

2) Add Core as a local package
   - File → Add Packages… → “Add Local…”.
   - Choose the `ios` folder (which contains `Package.swift`).
   - Add product: `ImageToPDFCore` to your app target.

3) Add app UI sources
   - Drag `ios/App` folder into your Xcode project (Create groups). Ensure your app target is checked.
   - In files that use core types (e.g., `ios/App/ViewModels/ScanViewModel.swift`), add:
     `import ImageToPDFCore`

4) Link Apple frameworks
   - Add: Vision, PDFKit, PhotosUI (same as Option A, step 3).

5) Signing and run
   - Same as Option A, step 5.

Notes
- No photo library permission is required for `PhotosPicker`.
- Vision/PDFKit are activated by conditional compilation (`#if canImport`), so the Core compiles on non‑iOS hosts, but features light up on iOS.
- The provided ImageFX/PDF text layer are minimal; extend per SPEC.md as needed.

