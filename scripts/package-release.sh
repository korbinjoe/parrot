#!/usr/bin/env bash
# Package a tested Apple silicon app without rebuilding or changing its signature.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
APP="${1:-$ROOT/build/Parrot.app}"
VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$APP/Contents/Info.plist")"
OUT="${2:-$ROOT/build/release/$VERSION}"
[[ "$VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || { echo "Invalid app version: $VERSION" >&2; exit 1; }
[[ "$(lipo -archs "$APP/Contents/MacOS/Parrot")" == "arm64" ]] || { echo "Expected an arm64 app" >&2; exit 1; }
codesign --verify --deep --strict "$APP"
mkdir -p "$OUT"
OUT="$(cd "$OUT" && pwd)"
NAME="Parrot-$VERSION-arm64"
[[ ! -e "$OUT/$NAME.zip" && ! -e "$OUT/$NAME.dmg" ]] || { echo "Release assets already exist in $OUT" >&2; exit 1; }

STAGING="$(mktemp -d -t parrot-release)"
trap 'rm -rf "$STAGING"' EXIT
ditto "$APP" "$STAGING/Parrot.app"
ln -s /Applications "$STAGING/Applications"
ditto -c -k --sequesterRsrc --keepParent "$APP" "$OUT/$NAME.zip"
hdiutil create -volname "Parrot $VERSION" -srcfolder "$STAGING" -fs HFS+ \
  -format UDZO -imagekey zlib-level=9 "$OUT/$NAME.dmg"
(
  cd "$OUT"
  shasum -a 256 "$NAME.dmg" "$NAME.zip" > SHA256SUMS.txt
)
echo "Packaged $OUT/$NAME.dmg and $OUT/$NAME.zip"
