#!/usr/bin/env bash
# Assembles Quota.app from the SwiftPM build product.
# Usage: scripts/make_app.sh [debug|release]   (default: release)
set -euo pipefail

CONFIG="${1:-release}"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
APP="$ROOT/Quota.app"
BIN="$ROOT/.build/$CONFIG/Quota"

echo "▶ swift build -c $CONFIG"
swift build -c "$CONFIG" --package-path "$ROOT"

echo "▶ assembling $APP"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN" "$APP/Contents/MacOS/Quota"
cp "$ROOT/Resources/Info.plist" "$APP/Contents/Info.plist"

# Ad-hoc code signature so Keychain / UserNotifications / ASWebAuth work locally.
echo "▶ ad-hoc codesign"
codesign --force --deep --sign - "$APP" >/dev/null 2>&1 || \
  echo "  (codesign skipped/failed — app still runs unsigned for local dev)"

echo "✓ built $APP"
