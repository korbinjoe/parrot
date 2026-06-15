#!/usr/bin/env bash
# Sign, package, and notarize OpenBob.app for distribution.
#
# Prerequisites (set as env vars before running):
#   DEVELOPER_ID        e.g. "Developer ID Application: Your Name (TEAMID)"
#   NOTARY_PROFILE      a notarytool keychain profile created via:
#                         xcrun notarytool store-credentials NOTARY_PROFILE \
#                           --apple-id you@example.com --team-id TEAMID --password <app-specific-pw>
#
# Usage: DEVELOPER_ID="..." NOTARY_PROFILE="..." bash scripts/notarize.sh
set -euo pipefail

APP="build/OpenBob.app"
ZIP="build/OpenBob.zip"

: "${DEVELOPER_ID:?Set DEVELOPER_ID to your 'Developer ID Application' identity}"
: "${NOTARY_PROFILE:?Set NOTARY_PROFILE to your notarytool keychain profile}"

echo "==> Building app bundle"
bash scripts/build-app.sh

echo "==> Code signing with hardened runtime: $DEVELOPER_ID"
codesign --force --options runtime --timestamp \
  --sign "$DEVELOPER_ID" \
  "$APP"

echo "==> Verifying signature"
codesign --verify --strict --verbose=2 "$APP"

echo "==> Zipping for notarization"
rm -f "$ZIP"
/usr/bin/ditto -c -k --keepParent "$APP" "$ZIP"

echo "==> Submitting to Apple notary service (this may take a few minutes)"
xcrun notarytool submit "$ZIP" --keychain-profile "$NOTARY_PROFILE" --wait

echo "==> Stapling notarization ticket"
xcrun stapler staple "$APP"
xcrun stapler validate "$APP"

echo "==> Done. Notarized bundle: $APP"
