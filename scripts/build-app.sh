#!/usr/bin/env bash
# Build OpenBob.app — a menu-bar agent bundle from the SPM executable.
# Requires full Xcode (for AppKit/SwiftUI/Vision). Run: bash scripts/build-app.sh
set -euo pipefail

export DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
CONFIG="${1:-release}"

echo "==> swift build ($CONFIG)"
swift build -c "$CONFIG" --product OpenBob

BIN="$(swift build -c "$CONFIG" --product OpenBob --show-bin-path)/OpenBob"
APP="$ROOT/build/OpenBob.app"
MACOS="$APP/Contents/MacOS"
RES="$APP/Contents/Resources"

echo "==> assembling $APP"
rm -rf "$APP"
mkdir -p "$MACOS" "$RES"
cp "$BIN" "$MACOS/OpenBob"
cp "$ROOT/Resources/Info.plist" "$APP/Contents/Info.plist"

# Ad-hoc sign so TCC (Accessibility / Screen Recording) can attribute permissions stably.
codesign --force --deep --sign - "$APP" >/dev/null 2>&1 || echo "  (codesign skipped)"

echo "==> done: $APP"
echo "    Launch: open \"$APP\"  (grant Accessibility + Screen Recording on first use)"
