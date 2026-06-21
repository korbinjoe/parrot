---
name: parrot-ios-debugging
description: Build, test, launch, screenshot, and troubleshoot the Parrot iOS app and Share Extension. Use when working on Apps/iOS, project.yml, iOS schemes, simulator validation, App Group handoff, UI tests, screenshots, or Xcode/iOS build failures in this repo.
---

# Parrot iOS Debugging

Use this workflow for Parrot iOS implementation and validation. Prefer the full Xcode toolchain explicitly; this machine may have `xcode-select` pointed at Command Line Tools.

## Standard Loop

Regenerate the project after editing `project.yml`:

```bash
xcodegen generate
```

Run package tests:

```bash
swift test
```

Build the iOS app:

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
xcodebuild -project Parrot.xcodeproj -scheme ParrotiOS \
-destination 'platform=iOS Simulator,name=iPhone 16' \
-derivedDataPath build/DerivedData CODE_SIGNING_ALLOWED=NO build
```

Build the Share Extension directly:

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
xcodebuild -project Parrot.xcodeproj -scheme ParrotShareExtension \
-destination 'platform=iOS Simulator,name=iPhone 16' \
-derivedDataPath build/DerivedData CODE_SIGNING_ALLOWED=NO build
```

Run iOS UI tests:

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
xcodebuild -project Parrot.xcodeproj -scheme ParrotiOSUITests \
-destination 'platform=iOS Simulator,name=iPhone 16' \
-derivedDataPath build/DerivedData CODE_SIGNING_ALLOWED=NO test
```

Also run `swift build` when checking that iOS changes did not regress the existing macOS package executable.

## Simulator Launch

Known simulator IDs in this workspace:

```text
iPhone 16: 286695E4-E3E6-424B-AD0B-7F37F6260602
iPhone SE 3rd gen: 0FE286CA-6F03-45B1-92BD-37ACF00ED80E
iPhone 16 Pro Max: F9FF4EE0-8346-40DB-8A4C-8BF9EC29E43B
```

Install, launch, and screenshot:

```bash
UDID=286695E4-E3E6-424B-AD0B-7F37F6260602
APP=build/DerivedData/Build/Products/Debug-iphonesimulator/ParrotiOS.app

DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcrun simctl boot "$UDID" 2>/dev/null || true
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcrun simctl bootstatus "$UDID" -b
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcrun simctl uninstall "$UDID" dev.parrot.ios 2>/dev/null || true
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcrun simctl install "$UDID" "$APP"
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcrun simctl launch "$UDID" dev.parrot.ios
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcrun simctl io "$UDID" screenshot build/screenshots/ios-iphone16-light.png
```

Set visual modes before launch when doing UI acceptance:

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcrun simctl ui "$UDID" appearance dark
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcrun simctl ui "$UDID" content_size accessibility-large
```

## Acceptance Checks

Capture at least:

- `build/screenshots/ios-iphone16-light.png`
- `build/screenshots/ios-iphone-se-light.png`
- `build/screenshots/ios-iphone16-pro-max-light.png`
- `build/screenshots/ios-iphone16-dark-accessibility.png`

Inspect screenshots for first-launch paste prompts, dark-mode contrast, text clipping, tab-bar overlap, and dynamic-type behavior. The app must not read clipboard on launch; clipboard reads should happen only after the user taps the explicit clipboard action.

Run boundary checks when touching shared modules:

```bash
rg -n "import (AppKit|UIKit|SwiftUI|Carbon|ApplicationServices)" Sources/ParrotCore Sources/ParrotSocial Sources/ParrotPlatform || true
rg -n "ParrotApp|ParrotPlatformMac|ParrotPlugins|AppKit|Carbon|ApplicationServices" Apps/iOS Sources/ParrotPlatformiOS || true
```

## Troubleshooting

- If `xcodebuild` cannot find iOS SDKs, set `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer`.
- If UI tests fail with SpringBoard or simulator `Busy`, reboot the target simulator and rerun the exact test command.
- If the Share Extension cannot build or embed, regenerate with `xcodegen generate` and confirm `ParrotShareExtension` has an explicit scheme and App Group entitlement.
- If App Group handoff behaves oddly in simulator, uninstall the app before reinstalling; stale container state can mask consume-once behavior.
- If code signing blocks local simulator builds, keep `CODE_SIGNING_ALLOWED=NO` for validation builds.
