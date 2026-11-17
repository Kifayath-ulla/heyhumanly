#!/bin/zsh
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
mkdir -p "$ROOT/work/module-cache"
export CLANG_MODULE_CACHE_PATH="$ROOT/work/module-cache"
if ! swift build -c release; then
  echo "Release build unavailable; building a local debug app."
  swift build --build-system native --disable-sandbox -c debug
  BINARY="$ROOT/.build/debug/HeyHumanly"
else
  BINARY="$ROOT/.build/release/HeyHumanly"
fi
APP="$ROOT/HeyHumanly.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BINARY" "$APP/Contents/MacOS/HeyHumanly"
cp Resources/Info.plist "$APP/Contents/Info.plist"
cp Resources/HeyHumanly.icns "$APP/Contents/Resources/HeyHumanly.icns"
# Sign with the local dev identity when present so macOS keeps Accessibility permission across rebuilds
# (ad-hoc signatures change every build). Falls back to ad-hoc signing.
DEV_DIR="$HOME/Library/Application Support/HeyHumanlyDev"
DEV_KC="$HOME/Library/Keychains/heyhumanly-dev.keychain-db"
if [ -f "$DEV_DIR/kc-pass" ] && [ -f "$DEV_KC" ]; then
  security unlock-keychain -p "$(cat "$DEV_DIR/kc-pass")" "$DEV_KC" >/dev/null 2>&1 || true
  if codesign --force --deep --keychain "$DEV_KC" --sign "HeyHumanly Local Dev" "$APP" >/dev/null 2>&1; then
    echo "Signed with HeyHumanly Local Dev"
  else
    codesign --force --deep --sign - "$APP" >/dev/null 2>&1 || true
    echo "Signed ad-hoc (dev identity failed)"
  fi
else
  codesign --force --deep --sign - "$APP" >/dev/null 2>&1 || true
  echo "Signed ad-hoc"
fi
test -x "$APP/Contents/MacOS/HeyHumanly"
echo "Built $APP"
