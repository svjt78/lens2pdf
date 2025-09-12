SHELL := /bin/bash
.DEFAULT_GOAL := help

FLUTTER := $(shell command -v flutter 2>/dev/null)
POD := $(shell command -v pod 2>/dev/null)

# Pass-through flags for Flutter commands.
# Example: make run-ios-sim ARGS="--release --dart-define=FOO=bar"
ARGS ?=

.PHONY: help setup create pubget pods run run-android run-ios run-ios-sim boot-sim test analyze clean doctor print-permissions android-permissions ios-permissions

help: ## Show common targets
	@echo "Flutter app Makefile"
	@echo
	@echo "Targets:"
	@echo "  make setup           - Create platforms and fetch deps"
	@echo "  make create          - Run 'flutter create' for android/ios"
	@echo "  make pubget          - Run 'flutter pub get'"
	@echo "  make pods            - Install CocoaPods in ios/ (if available)"
	@echo "  make run             - Run on the default device"
	@echo "  make run-android     - Run on Android device/emulator"
	@echo "  make run-ios         - Run on iOS Simulator/device"
	@echo "  make boot-sim        - Open and boot iOS Simulator (SIMULATOR_NAME=\"iPhone 15\")"
	@echo "  make run-ios-sim     - Boot sim then run on named simulator (SIMULATOR_NAME=...)"
	@echo "  make test            - Run flutter tests"
	@echo "  make analyze         - Run static analyzer"
	@echo "  make clean           - Clean Flutter build artifacts"
	@echo "  make doctor          - Run flutter doctor and list devices"
	@echo "  make print-permissions - Print required platform permissions"
	@echo "  make android-permissions - Insert Android camera permission (idempotent)"
	@echo "  make ios-permissions     - Insert iOS camera usage key (idempotent)"
	@echo "  (append extra flags via ARGS=\"--release --dart-define=KEY=VAL\")"

setup: create pubget pods ## Create platforms and fetch dependencies
	@echo "Setup complete. Next: 'make print-permissions' and then 'make run'"

create: ## Scaffold android/ios folders (idempotent)
	@if [ -z "$(FLUTTER)" ]; then echo "Flutter not found. Install Flutter then re-run."; exit 1; fi
	flutter create --platforms=android,ios .

pubget: ## Fetch Dart dependencies
	@if [ -z "$(FLUTTER)" ]; then echo "Flutter not found. Install Flutter then re-run."; exit 1; fi
	flutter pub get

pods: ## Install CocoaPods (iOS)
	@if [ ! -d ios ]; then echo "iOS folder not found. Run 'make create' first."; exit 0; fi
	@if [ -z "$(POD)" ]; then echo "CocoaPods not found. Install via 'sudo gem install cocoapods'"; exit 0; fi
	cd ios && pod install

run: ## Run app on default device
	@if [ -z "$(FLUTTER)" ]; then echo "Flutter not found. Install Flutter then re-run."; exit 1; fi
	flutter run $(ARGS)

run-android: ## Run app on Android
	@if [ -z "$(FLUTTER)" ]; then echo "Flutter not found. Install Flutter then re-run."; exit 1; fi
	flutter run -d android $(ARGS)

run-ios: ## Run app on iOS
	@if [ -z "$(FLUTTER)" ]; then echo "Flutter not found. Install Flutter then re-run."; exit 1; fi
	flutter run -d ios $(ARGS)

SIMULATOR_NAME ?= iPhone 15

boot-sim: ## Open and boot the iOS Simulator (override with SIMULATOR_NAME=...)
	@echo "Opening Simulator and booting '$(SIMULATOR_NAME)'..."
	open -a Simulator || true
	# Try to boot by name; it's safe if already booted
	@xcrun simctl boot "$(SIMULATOR_NAME)" 2>/dev/null || true
	@echo "If the device isn't installed, add it in Xcode → Settings → Platforms."

run-ios-sim: boot-sim ## Boot simulator then run on it (override with SIMULATOR_NAME=...)
	@if [ -z "$(FLUTTER)" ]; then echo "Flutter not found. Install Flutter then re-run."; exit 1; fi
	flutter run -d "$(SIMULATOR_NAME)" $(ARGS)

test: ## Run tests
	@if [ -z "$(FLUTTER)" ]; then echo "Flutter not found. Install Flutter then re-run."; exit 1; fi
	flutter test $(ARGS)

analyze: ## Lint/Analyze
	@if [ -z "$(FLUTTER)" ]; then echo "Flutter not found. Install Flutter then re-run."; exit 1; fi
	flutter analyze $(ARGS)

clean: ## Clean build artifacts
	@if [ -z "$(FLUTTER)" ]; then echo "Flutter not found. Install Flutter then re-run."; exit 1; fi
	flutter clean

doctor: ## Show flutter doctor and devices
	@if [ -z "$(FLUTTER)" ]; then echo "Flutter not found. Install Flutter then re-run."; exit 1; fi
	flutter doctor
	flutter devices

print-permissions: ## Print required platform permissions to review/apply
	@echo "Android: ensure this line is present in android/app/src/main/AndroidManifest.xml (inside <manifest>):"
	@echo "  <uses-permission android:name=\"android.permission.CAMERA\"/>"
	@echo "  <uses-permission android:name=\"android.permission.READ_MEDIA_IMAGES\"/>  # Android 13+ for gallery access"
	@echo
	@echo "iOS: add these keys to ios/Runner/Info.plist:"
	@echo "  <key>NSCameraUsageDescription</key>"
	@echo "  <string>Capture documents using the camera.</string>"
	@echo "  <key>NSPhotoLibraryUsageDescription</key>"
	@echo "  <string>Import images from your photo library.</string>"

android-permissions: ## Add CAMERA permission to AndroidManifest (idempotent)
	@if [ ! -d android ]; then echo "Android folder not found. Run 'make create' first."; exit 1; fi
	MANIFEST=android/app/src/main/AndroidManifest.xml; \
	if ! grep -q 'android.permission.CAMERA' "$$MANIFEST" 2>/dev/null; then \
	  echo "Updating $$MANIFEST with CAMERA permission"; \
	  awk 'BEGIN{added=0} /<manifest/{print; print "    <uses-permission android:name=\"android.permission.CAMERA\"/>"; added=1; next} {print} END{if(!added) print "    <uses-permission android:name=\"android.permission.CAMERA\"/>"}' "$$MANIFEST" > "$$MANIFEST.tmp" && mv "$$MANIFEST.tmp" "$$MANIFEST"; \
	else \
	  echo "CAMERA permission already present in $$MANIFEST"; \
	fi

ios-permissions: ## Add NSCameraUsageDescription to Info.plist (idempotent)
	@if [ ! -d ios ]; then echo "iOS folder not found. Run 'make create' first."; exit 1; fi
	PLIST=ios/Runner/Info.plist; \
	if ! grep -q '<key>NSCameraUsageDescription</key>' "$$PLIST" 2>/dev/null; then \
	  echo "Updating $$PLIST with NSCameraUsageDescription"; \
	  awk 'BEGIN{added=0} /<\/dict>/{print "  <key>NSCameraUsageDescription</key>\n  <string>Capture documents using the camera.</string>"; print; added=1; next} {print} END{if(!added) print "  <key>NSCameraUsageDescription</key>\n  <string>Capture documents using the camera.</string>"}' "$$PLIST" > "$$PLIST.tmp" && mv "$$PLIST.tmp" "$$PLIST"; \
	else \
	  echo "NSCameraUsageDescription already present in $$PLIST"; \
	fi
	@PLIST=ios/Runner/Info.plist; \
	if ! grep -q '<key>NSPhotoLibraryUsageDescription</key>' "$$PLIST" 2>/dev/null; then \
	  echo "Updating $$PLIST with NSPhotoLibraryUsageDescription"; \
	  awk 'BEGIN{added=0} /<\/dict>/{print "  <key>NSPhotoLibraryUsageDescription</key>\n  <string>Import images from your photo library.</string>"; print; added=1; next} {print} END{if(!added) print "  <key>NSPhotoLibraryUsageDescription</key>\n  <string>Import images from your photo library.</string>"}' "$$PLIST" > "$$PLIST.tmp" && mv "$$PLIST.tmp" "$$PLIST"; \
	else \
	  echo "NSPhotoLibraryUsageDescription already present in $$PLIST"; \
	fi
