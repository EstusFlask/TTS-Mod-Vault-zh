#!/usr/bin/env bash
# Build and package the relocatable Flutter Linux bundle as a ZIP distribution.
# Run on x86_64 Linux: bash packaging/linux/build_zip.sh

set -euo pipefail

APP_SLUG="TTS-Mod-Vault-zh"
ARCH="x64"

ROOT="$(git -C "$(dirname "${BASH_SOURCE[0]}")" rev-parse --show-toplevel)"
cd "$ROOT"

if command -v fvm >/dev/null 2>&1; then
  FLUTTER=(fvm flutter)
else
  FLUTTER=(flutter)
fi

VERSION="$(sed -n 's/^version:[[:space:]]*\([^+[:space:]]*\).*/\1/p' pubspec.yaml | head -1)"
[ -n "$VERSION" ] || { echo "ERROR: could not read version from pubspec.yaml"; exit 1; }

DIST_NAME="${APP_SLUG}-${VERSION}-linux-${ARCH}"
DIST_ROOT="build/distributions"
STAGE="$DIST_ROOT/$DIST_NAME"
OUT_ZIP="$DIST_ROOT/$DIST_NAME.zip"

echo "==> building $DIST_NAME"
"${FLUTTER[@]}" build linux --release

BUNDLE="build/linux/x64/release/bundle"
[ -x "$BUNDLE/tts_mod_vault" ] || {
  echo "ERROR: built executable not found at $BUNDLE/tts_mod_vault"
  exit 1
}
[ -f "$BUNDLE/lib/libpdfium.so" ] || {
  echo "ERROR: libpdfium.so is missing from the Linux bundle"
  exit 1
}

rm -rf "$STAGE"
rm -f "$OUT_ZIP"
mkdir -p "$STAGE"
cp -a "$BUNDLE/." "$STAGE/"
cp LICENSE "$STAGE/LICENSE"

(
  cd "$DIST_ROOT"
  zip -r -9 -q "$(basename "$OUT_ZIP")" "$DIST_NAME"
)

echo "==> verifying archive"
unzip -tq "$OUT_ZIP"

echo "==> done: $OUT_ZIP"

