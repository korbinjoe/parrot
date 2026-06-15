#!/usr/bin/env bash
# Build Parrot.app — a menu-bar agent bundle from the SPM executable.
# Requires full Xcode (for AppKit/SwiftUI/Vision). Run: bash scripts/build-app.sh
set -euo pipefail

export DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
CONFIG="${1:-release}"

echo "==> swift build ($CONFIG)"
swift build -c "$CONFIG" --product Parrot

BIN="$(swift build -c "$CONFIG" --product Parrot --show-bin-path)/Parrot"
APP="$ROOT/build/Parrot.app"
MACOS="$APP/Contents/MacOS"
RES="$APP/Contents/Resources"

echo "==> assembling $APP"
rm -rf "$APP"
mkdir -p "$MACOS" "$RES"
cp "$BIN" "$MACOS/Parrot"
cp "$ROOT/Resources/Info.plist" "$APP/Contents/Info.plist"

# Sign with a stable identity so TCC (Accessibility / Screen Recording) grants survive rebuilds.
# A self-signed "OpenBob Dev" cert gives a designated requirement keyed to the certificate
# (not the cdhash), so re-signing a fresh binary keeps the same DR and the OS keeps the grant.
# NOTE: the cert name is "OpenBob Dev" for historical reasons — it's a local dev cert and its
# name has no functional bearing on the app (bundle id com.parrot.app). Reusing it keeps the
# designated requirement stable across rebuilds. Falls back to ad-hoc when the cert is absent.
SIGN_IDENTITY="${PARROT_SIGN_IDENTITY:-OpenBob Dev}"
if security find-certificate -c "$SIGN_IDENTITY" >/dev/null 2>&1; then
    codesign --force --deep --sign "$SIGN_IDENTITY" "$APP" >/dev/null 2>&1 \
        && echo "  signed with: $SIGN_IDENTITY (TCC grants persist across rebuilds)" \
        || { echo "  (signing with '$SIGN_IDENTITY' failed, falling back to ad-hoc)"; codesign --force --deep --sign - "$APP" >/dev/null 2>&1; }
else
    echo "  ('$SIGN_IDENTITY' cert not found, using ad-hoc — Accessibility grant resets each rebuild)"
    codesign --force --deep --sign - "$APP" >/dev/null 2>&1 || echo "  (codesign skipped)"
fi

echo "==> done: $APP"
echo "    Launch: open \"$APP\"  (grant Accessibility + Screen Recording on first use)"
