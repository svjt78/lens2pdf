# Flutter Tooling Known Issues

## Flutter cache writes blocked under `~/Documents`
- **Symptoms**
  - `flutter doctor` and `flutter run` die with `The flutter tool cannot access the file or directory.`
  - Doctor stalls on downloading `fonts.zip` under `flutter/bin/cache/artifacts/material_fonts`.
  - Running from Codex CLI shows `update_engine_version.sh` failures writing to `engine.stamp`.
- **Root cause**
  - The Flutter SDK was expanded inside `~/Documents/...` on macOS, so Gatekeeper left `com.apple.quarantine` attributes on most files.
  - Those attributes plus inherited ACLs caused write attempts inside `flutter/bin/cache` to be rejected even after ownership changes.
- **Fix**
  1. Grant the terminal app **Full Disk Access** (`System Settings → Privacy & Security → Full Disk Access`).
  2. Recursively clear quarantine metadata and reset permissions on the SDK:
     ```bash
     sudo xattr -dr com.apple.quarantine /Users/suvojitdutta/Documents/Rest/apps/apps/flutter
     sudo chmod -R u+rwX /Users/suvojitdutta/Documents/Rest/apps/apps/flutter
     ```
  3. If the fonts download still fails, manually unzip the cached bundle:
     ```bash
     cd /Users/suvojitdutta/Documents/Rest/apps/apps/flutter/bin/cache
     unzip -o downloads/storage.googleapis.com/flutter_infra_release/flutter/fonts/3012db47f3130e62f7cc0beabff968a33cbec8d8/fonts.zip \
       -d artifacts/material_fonts
     ```
  4. Re-run `flutter doctor` to rebuild the cache (it should now succeed).

## `flutter run` invoked from the home directory
- **Symptoms**
  - `flutter run --release` prints `Error: No pubspec.yaml file found. This command should be run from the root of your Flutter project.`
- **Root cause**
  - The command was executed from `~/` instead of the project directory that contains `pubspec.yaml`.
- **Fix**
  ```bash
  cd /Users/suvojitdutta/Documents/Rest/apps/apps/OCR/image-to-pdf/mobile_app
  flutter run --release
  ```

Keeping these notes handy should make future Flutter setup issues faster to diagnose on macOS machines where the SDK lives under `~/Documents`.

