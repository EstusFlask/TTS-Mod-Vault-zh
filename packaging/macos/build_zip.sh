#!/usr/bin/env bash
# Build and package the Flutter macOS app as a ZIP distribution.
# Run on macOS: bash packaging/macos/build_zip.sh

set -euo pipefail

APP_NAME="TTS Mod Vault"
APP_SLUG="TTS-Mod-Vault-zh"
ARCH="universal"

ROOT="$(git -C "$(dirname "${BASH_SOURCE[0]}")" rev-parse --show-toplevel)"
cd "$ROOT"

if [ "$(uname -s)" != "Darwin" ]; then
  echo "ERROR: this script must run on macOS"
  exit 1
fi

if command -v fvm >/dev/null 2>&1; then
  FLUTTER=(fvm flutter)
else
  FLUTTER=(flutter)
fi

VERSION="$(sed -n 's/^version:[[:space:]]*\([^+[:space:]]*\).*/\1/p' pubspec.yaml | head -1)"
[ -n "$VERSION" ] || { echo "ERROR: could not read version from pubspec.yaml"; exit 1; }

DIST_NAME="${APP_SLUG}-${VERSION}-macos-${ARCH}"
DIST_ROOT="build/distributions"
OUT_ZIP="$DIST_ROOT/$DIST_NAME.zip"

echo "==> building $DIST_NAME"
if [ "${SKIP_CLEAN:-0}" != "1" ]; then
  "${FLUTTER[@]}" clean >/dev/null
fi
"${FLUTTER[@]}" build macos --release

APP="build/macos/Build/Products/Release/${APP_NAME}.app"
[ -d "$APP" ] || { echo "ERROR: built app not found at $APP"; exit 1; }
[ -e "$APP/Contents/Frameworks/pdfium.framework/pdfium" ] || {
  echo "ERROR: pdfium.framework is missing from the macOS app"
  exit 1
}

ACTUAL_ARCHS="$(lipo -archs "$APP/Contents/MacOS/$APP_NAME")"
if [[ " $ACTUAL_ARCHS " != *" x86_64 "* || " $ACTUAL_ARCHS " != *" arm64 "* ]]; then
  echo "ERROR: expected a universal x86_64 + arm64 executable, got: $ACTUAL_ARCHS"
  exit 1
fi

echo "==> verifying code signature"
codesign --verify --deep --strict --verbose=2 "$APP"

mkdir -p "$DIST_ROOT"
rm -f "$OUT_ZIP"
# ditto preserves the .app bundle's symlinks, metadata, and executable modes.
ditto -c -k --sequesterRsrc --keepParent "$APP" "$OUT_ZIP"

echo "==> verifying archive"
unzip -tq "$OUT_ZIP"

echo "==> done: $OUT_ZIP"
echo "    This build is ad-hoc signed and not notarized."
