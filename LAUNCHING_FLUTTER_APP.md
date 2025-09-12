# Launching the Flutter App (Command-by-Command)

The Flutter project lives in `mobile_app/`. All commands below are meant to be run from the repo root unless noted.

Prerequisites (once)

```bash
# Verify Flutter and Xcode
flutter --version
xcodebuild -version

# (Optional) Install CocoaPods if missing
sudo gem install cocoapods
```

1) Set up the project (first time only)

```bash
# Create platforms and fetch dependencies
make setup

# Add iOS permission strings (idempotent)
make -C mobile_app ios-permissions

# (Android later) Ensure permissions are present
make -C mobile_app android-permissions
```

2) List devices (optional)

```bash
flutter devices
```

3) Run on iOS Simulator (default: iPhone 15)

```bash
# Boot the simulator (override name with SIMULATOR_NAME="iPhone 16")
make boot-sim

# Launch the app on that simulator
make run-ios-sim
```

4) Run on a physical iPhone (first-time signing)

```bash
# Open Xcode workspace, select a Team under Runner → Signing & Capabilities
open mobile_app/ios/Runner.xcworkspace

# Connect and unlock your iPhone; trust the developer on the device if prompted

# Run on your device (replace with id from `flutter devices`)
cd mobile_app && flutter run -d <your-device-id>
```

5) Run from VS Code (optional)

```bash
# Select the device in VS Code status bar, then press F5
```

Useful flags and variants

```bash
# Release mode
make run-ios-sim ARGS="--release"
make run-ios ARGS="--release"

# Dart defines
make run-ios-sim ARGS="--dart-define=FEATURE_FLAG=true --dart-define=API_URL=https://example.com"

# Analyze and test
make analyze
make test
```

Simulator camera note

- The iOS Simulator has no real camera. In Capture, the camera button is disabled and you can:
  - Use Import to pick images/PDFs from Photos or Files.
  - Use Add sample to insert a placeholder page.
- PDFs imported from Files appear directly in Library (no conversion). The snackbar includes a “Go to Library” action.

Troubleshooting

```bash
# If no devices are listed
flutter devices
open -a Simulator
xcrun simctl boot "iPhone 15"

# Reset unavailable simulators
xcrun simctl delete unavailable

# Inspect installed runtimes
xcrun simctl list runtimes
```

Tips

- Override simulator name: `make run-ios-sim SIMULATOR_NAME="iPhone 16"`.
- All Make targets accept extra Flutter flags via `ARGS="..."`.
